class BankSetup
  def initialize
    @nordigen = NordigenClient.new
    @bank_sync = BankSync.new
  end

  def sync_accounts
    @bank_sync.check_requisitions
    @bank_sync.sync_accounts
  end

  def list_institutions(country_code = "SE")
    institutions = @nordigen.list_institutions(country_code)
    institutions.map do |inst|
      {
        id: inst["id"],
        name: inst["name"],
        logo: inst["logo"],
        countries: inst["countries"].join(", ")
      }
    end
  end

  def create_requisition(institution_id)
    requisition = @nordigen.create_requisition(institution_id)

    # Store requisition in database
    Requisition.create(
      requisition_id: requisition["id"],
      institution_id: institution_id,
      status: requisition["status"],
      created_at: Time.now,
      last_synced_at: Time.now,
      expires_at: Time.now + (90 * 24 * 60 * 60) # 90 days
    )

    requisition["link"]
  end

  def recreate_requisition(optional_id)
    target = pick_requisition_to_recreate(optional_id)
    raise "No expired/suspended requisition or LN requisition with sick accounts found" unless target

    puts "Found requisition for #{target.institution_id} (status=#{target.status})"

    backfill_account_metadata(target)

    requisition = @nordigen.create_requisition(target.institution_id)

    target.update(
      requisition_id: requisition["id"],
      status: requisition["status"],
      last_synced_at: Time.now,
      expires_at: Time.now + (90 * 24 * 60 * 60) # 90 days
    )

    requisition["link"]
  end

  private

  def pick_requisition_to_recreate(optional_id)
    if optional_id && optional_id != true
      return Requisition.where(id: optional_id).first
    end

    candidate = Requisition.where(status: ["EX", "SU"]).all.sample
    return candidate if candidate

    Requisition.where(status: "LN").all.find do |req|
      Account.where(requisition_id: req.id, status: ["SUSPENDED", "ERROR", "EXPIRED"]).any?
    end
  end

  def backfill_account_metadata(requisition)
    Account.where(requisition_id: requisition.id).each do |account|
      metadata = @nordigen.get_account_metadata(account[:account_id])
      account.update(
        iban: metadata["iban"] || account.iban,
        owner_name: metadata["owner_name"] || account.owner_name,
        status: metadata["status"] || account.status
      )
    rescue => e
      puts "Warning: could not refresh metadata for account #{account[:account_id]}: #{e.message}"
    end
  end
end
