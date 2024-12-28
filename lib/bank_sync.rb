require_relative "nordigen_client"
require_relative "lunch_money_client"

class BankSync
  def initialize
    @nordigen = NordigenClient.new
    @lunch_money = LunchMoneyClient.new
  end

  def sync
    check_requisitions
    sync_accounts
    sync_transactions
  end

  def sync_accounts
    puts "Syncing accounts..."
    DB[:requisitions].where(status: "LN").each do |req|
      requisition = @nordigen.get_requisition(req[:requisition_id])
      puts "Syncing accounts for requisition: #{req[:requisition_id]}"

      requisition["accounts"].each do |account_id|
        puts "Syncing account: #{account_id}"
        metadata = @nordigen.get_account_metadata(account_id)
        details = @nordigen.get_account_details(account_id)
        puts "*" * 50
        puts metadata
        puts "*" * 50
        puts details

        name = details.dig("account", "name")
        status = metadata["status"]

        if (account = Account.where(account_id:).first)
          puts "Updating existing account"
          account.update(
            name: name || account.name,
            status: status,
            last_synced_at: Time.now
          )
        else
          puts "Creating new account"
          Account.create(
            account_id: account_id,
            requisition_id: req[:id],
            status: status,
            last_synced_at: Time.now,
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
    puts "Checking requisitions..."
    DB[:requisitions].each do |req|
      puts "Checking requisition: #{req[:requisition_id]}"
      requisition = @nordigen.get_requisition(req[:requisition_id])
      puts "Requisition status: #{requisition["status"]}"

      current_status = requisition["status"]
      if current_status != req[:status]
        DB[:requisitions].where(id: req[:id]).update(
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
        puts "No action required"
      end
    end
  end

  def sync_transactions
    puts "Syncing transactions..."
    Account.where(lunch_money_id: nil).invert.where(status: "READY").each do |account|
      puts "Syncing transactions for account: #{account[:account_id]}"
      response = @nordigen.get_account_transactions(account[:account_id])
      booked_transactions = response.dig("transactions", "booked")

      if booked_transactions
        puts "Found #{booked_transactions.size} transactions"
      else
        puts "No transactions found"
        if response["status_code"] >= 400
          notify_account_issue(account[:account_id], response["detail"])
        end

        next
      end

      @lunch_money.create_transactions(transactions: booked_transactions.map { |tx|
        puts "Creating transaction"
        puts tx
        {
          amount: tx["transactionAmount"]["amount"].to_f,
          external_id: tx["transactionId"],
          currency: tx["transactionAmount"]["currency"].downcase,
          date: tx["bookingDate"],
          payee: tx["creditorName"] || tx["remittanceInformationUnstructuredArray"]&.join(", "),
          status: "cleared",
          asset_id: account.lunch_money_id
        }
      })
    end
  end

  private

  def notify_expired_requisition(requisition)
    message = "Bank Sync: Connection Expired\n"
    message += "Bank connection expired for #{requisition[:institution_id]}. Please create a new requisition."
    pushover_message(message)
  end

  def notify_reauthorization_needed(requisition)
    message = "Bank Sync: Reauthorization Needed\n"
    message += "Bank connection needs reauthorization for #{requisition[:institution_id]}."
    pushover_message(message)
  end

  def notify_account_issue(account_id, status)
    message = "Bank Sync: Account Issue\n"
    message += "Account #{account_id} has status: #{status}."
    pushover_message(message)
  end

  def pushover_message(message)
    puts "Sending Pushover message"
    puts message
    Pushover::Message.new(token: ENV["PUSHOVER_TOKEN"], user: ENV["PUSHOVER_USER"], message:).push
  end
end
