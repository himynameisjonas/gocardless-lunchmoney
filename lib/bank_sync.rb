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

      requisition["accounts"].each do |account_id|
        LOGGER.info "Syncing account: #{account_id}"
        metadata = @nordigen.get_account_metadata(account_id)
        details = @nordigen.get_account_details(account_id)

        name = details.dig("account", "name")
        status = metadata["status"]

        if (account = Account.where(account_id:).first)
          account.update(
            name: name || account.name,
            status: status
          )
        else
          Account.create(
            account_id: account_id,
            requisition_id: req.id,
            status: status,
            name: name
          )
        end

        if status != "READY"
          notify_account_issue(account_id, status)
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
      booked_transactions = response.dig("transactions", "booked")
      account.update(last_synced_at: Time.now)

      if booked_transactions
        LOGGER.info "Found #{booked_transactions.size} transactions"
      else
        LOGGER.info "No transactions found"
        if response["status_code"] >= 400
          notify_account_issue(account[:account_id], response["detail"])
        end

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

  def notify_account_issue(account_id, status)
    message = "Bank Sync: Account Issue\n"
    message += "Account #{account_id} has status: #{status}."
    @pushover.push(message)
  end
end
