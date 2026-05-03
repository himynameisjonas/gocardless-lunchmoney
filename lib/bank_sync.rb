class BankSync
  SYNC_INTERVAL = 8 * 60 * 60 # 8 hours

  def initialize
    @nordigen = NordigenClient.new
    @lunch_money = LunchMoneyClient.new
    @pushover = Pushover.new
  end

  def sync
    check_requisitions
    sync_accounts
    fetch_transactions
    push_transactions
  end

  def sync_accounts
    LOGGER.info "Syncing accounts..."
    Requisition.where(status: "LN").each do |req|
      requisition = @nordigen.get_requisition(req.requisition_id)
      current_account_ids = requisition["accounts"]

      current_account_ids.each do |account_id|
        LOGGER.info "Syncing account: #{account_id}"
        metadata = @nordigen.get_account_metadata(account_id)
        details = @nordigen.get_account_details(account_id)

        iban = metadata["iban"]
        owner_name = metadata["owner_name"]
        status = metadata["status"]
        name = details.dig("account", "name") ||
               details.dig("account", "product") ||
               (metadata["name"].to_s.empty? ? nil : metadata["name"])

        account = Account.where(account_id: account_id).first
        account ||= reconcile_renamed_account(req, current_account_ids, iban, account_id)

        if account
          previous_status = account[:status]
          account.update(
            account_id: account_id,
            name: name || account.name,
            status: status,
            iban: iban || account.iban,
            owner_name: owner_name || account.owner_name
          )
          notify_status_change(account, previous_status, status) if previous_status != status
        else
          new_account = Account.create(
            account_id: account_id,
            requisition_id: req.id,
            status: status,
            name: name,
            iban: iban,
            owner_name: owner_name
          )
          notify_status_change(new_account, nil, status) if status != "READY"
        end
      end
    end
  end

  def check_requisitions
    LOGGER.info "Checking requisitions..."
    Requisition.each do |req|
      requisition = @nordigen.get_requisition(req.requisition_id)

      current_status = requisition["status"]
      if current_status != req.status
        Requisition.where(id: req.id).first.update(
          status: requisition["status"],
          last_synced_at: Time.now
        )
      end

      case current_status
      when "EX"
        notify_expired_requisition(req)
      when "SU" # Link Needed or Suspended
        notify_reauthorization_needed(req)
      else
        LOGGER.info "No action required"
      end
    end
  end

  def fetch_transactions
    LOGGER.info "Fetching transactions..."
    Account.where(lunch_money_id: nil).invert.where(status: "READY", last_synced_at: ..(Time.now - SYNC_INTERVAL)).each do |account|
      LOGGER.info "fetching transactions for account: #{account[:account_id]}"
      response = @nordigen.get_account_transactions(account[:account_id])

      if response["status_code"].to_i >= 400
        LOGGER.warn "Transactions fetch failed for #{account[:account_id]}: #{response["detail"]}"
        refresh_account_status(account)
        next
      end

      account.update(last_synced_at: Time.now)

      booked_transactions = response.dig("transactions", "booked")
      if booked_transactions
        LOGGER.info "Found #{booked_transactions.size} transactions"
      else
        LOGGER.info "No transactions found"
        next
      end

      booked_transactions.each do |tx|
        Transaction.find_or_create(external_id: tx["transactionId"]) do |t|
          t.data = tx
          t.account_id = account.id
        end
      end
    end
  end

  def push_transactions
    LOGGER.info "Pushing transactions..."
    Transaction.where(synced_at: nil).reverse_each do |transaction|
      @lunch_money.create_transactions(transactions: [transaction].map { |tx|
        {
          amount: tx.data["transactionAmount"]["amount"].to_f,
          external_id: tx.data["transactionId"],
          currency: tx.data["transactionAmount"]["currency"].downcase,
          date: tx.data["valueDate"] || tx.data["bookingDate"],
          payee: tx.data["creditorName"] || tx.data["remittanceInformationUnstructuredArray"]&.join(", "),
          status: "cleared",
          asset_id: tx.account.lunch_money_id
        }
      })
      transaction.update(synced_at: Time.now)
    rescue => e
      if e.message.match?(/Key.*user_external_id.*already exists./)
        transaction.update(synced_at: Time.now, error: e.message)
      else
        transaction.update(synced_at: nil, error: e.message)
      end
    end
  end

  private

  def reconcile_renamed_account(req, current_account_ids, iban, new_account_id)
    return nil if iban.to_s.empty?

    candidates = Account.where(requisition_id: req.id, iban: iban)
                        .exclude(account_id: current_account_ids).all

    case candidates.size
    when 1
      LOGGER.info "Reconciling renamed account: #{candidates.first.account_id} -> #{new_account_id}"
      candidates.first
    when 0
      nil
    else
      LOGGER.warn "Ambiguous reconciliation for IBAN #{iban} in requisition #{req.id}"
      @pushover.push(
        "Bank Sync: Ambiguous account match\n" \
        "Multiple existing accounts share IBAN #{iban}. New account_id #{new_account_id} " \
        "was created as a fresh row — relink with `setup --map_account #{new_account_id} --map_asset <ASSET_ID>`."
      )
      nil
    end
  end

  def refresh_account_status(account)
    metadata = @nordigen.get_account_metadata(account[:account_id])
    new_status = metadata["status"]
    previous_status = account[:status]
    account.update(
      status: new_status,
      iban: metadata["iban"] || account.iban,
      owner_name: metadata["owner_name"] || account.owner_name
    )
    notify_status_change(account, previous_status, new_status) if previous_status != new_status
  end

  def notify_expired_requisition(requisition)
    message = "Bank Sync: Connection Expired\n"
    message += "Bank connection expired for #{requisition[:institution_id]}. Please recreate the requisition."
    @pushover.push(message)
  end

  def notify_reauthorization_needed(requisition)
    message = "Bank Sync: Reauthorization Needed\n"
    message += "Bank connection needs reauthorization for #{requisition[:institution_id]}."
    @pushover.push(message)
  end

  def notify_status_change(account, previous_status, new_status)
    label = account[:name].to_s.empty? ? account[:account_id] : "#{account[:name]} (#{account[:account_id]})"
    message = if new_status == "READY"
      "Bank Sync: Account Recovered\n#{label} is back to READY."
    elsif previous_status.nil?
      "Bank Sync: Account Issue\n#{label} synced with status #{new_status}."
    else
      "Bank Sync: Account Issue\n#{label} status changed: #{previous_status} -> #{new_status}."
    end
    @pushover.push(message)
  end
end
