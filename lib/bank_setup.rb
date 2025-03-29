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
    expired_requisition = if optional_id && optional_id != true
      Requisition.where(id: optional_id).first
    else
      Requisition.where(status: "EX").all.sample
    end
    raise "No expired requisition found" unless expired_requisition

    puts "Found a expired #{expired_requisition.institution_id} requisition"

    requisition = @nordigen.create_requisition(expired_requisition.institution_id)

    # Store requisition in database
    expired_requisition.update(
      requisition_id: requisition["id"],
      institution_id: expired_requisition.institution_id,
      status: requisition["status"],
      last_synced_at: Time.now,
      expires_at: Time.now + (90 * 24 * 60 * 60) # 90 days
    )

    requisition["link"]
  end
end
