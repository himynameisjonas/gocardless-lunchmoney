require_relative "nordigen_client"
require_relative "lunch_money_client"

class BankSync
  def initialize
    @nordigen = NordigenClient.new
    @lunch_money = LunchMoneyClient.new(
      access_token: ENV.fetch("LUNCH_MONEY_TOKEN")
    )
  end

  def sync
    check_requisitions
    sync_accounts
    sync_transactions
  end

  private

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

  def sync_accounts
    puts "Syncing accounts..."
    DB[:requisitions].where(status: "LN").each do |req|
      requisition = @nordigen.get_requisition(req[:requisition_id])
      puts "Syncing accounts for requisition: #{req[:requisition_id]}"

      requisition["accounts"].each do |account_id|
        puts "Syncing account: #{account_id}"
        status = @nordigen.get_account_metadata(account_id)["status"]

        if (account = DB[:accounts].where(account_id: account_id).first)
          account.update(
            status: status,
            last_synced_at: Time.now
          )
        else
          DB[:accounts].insert(
            account_id: account_id,
            requisition_id: req[:id],
            status: status,
            last_synced_at: Time.now
          )
        end

        if status != "READY"
          notify_account_issue(account_id, status, req)
        end
      end
    end
  end

  def sync_transactions
    puts "Syncing transactions..."
    DB[:accounts].where(status: "READY").each do |acc|
      puts "Syncing transactions for account: #{acc[:account_id]}"
      transactions = @nordigen.get_account_transactions(acc[:account_id])
      booked_transactions = transactions["transactions"]["booked"]

      booked_transactions.each do |tx|
        puts "Creating transaction: #{tx["transactionId"]}"
        # @lunch_money.create_transaction(
        #   date: tx["bookingDate"],
        #   amount: tx["transactionAmount"]["amount"].to_f,
        #   currency: tx["transactionAmount"]["currency"],
        #   payee: tx["remittanceInformationUnstructured"],
        #   notes: "Imported from bank",
        #   external_id: tx["transactionId"]
        # )
      rescue LunchMoney::Error => e
        next if e.message.include?("external_id already exists")
        raise
      end
    end
  end

  def notify_expired_requisition(requisition)
    message = "Bank Sync: Connection Expired\n"
    message += "Bank connection expired for #{requisition[:institution_id]}. Please create a new requisition."
    Pushover::Message.new(token: ENV["PUSHOVER_TOKEN"], user: ENV["PUSHOVER_USER"], message:).push
  end

  def notify_reauthorization_needed(requisition)
    message = "Bank Sync: Reauthorization Needed\n"
    message += "Bank connection needs reauthorization for #{requisition[:institution_id]}."
    Pushover::Message.new(token: ENV["PUSHOVER_TOKEN"], user: ENV["PUSHOVER_USER"], message:).push
  end

  def notify_account_issue(account_id, status, requisition)
    message = "Bank Sync: Account Issue\n"
    message += "Account #{account_id} has status: #{status}. Institution: #{requisition[:institution_id]}"
    Pushover::Message.new(token: ENV["PUSHOVER_TOKEN"], user: ENV["PUSHOVER_USER"], message:).push
  end
end
