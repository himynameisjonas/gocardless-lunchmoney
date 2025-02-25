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
    Requsition.create(
      requisition_id: requisition["id"],
      institution_id: institution_id,
      status: requisition["status"],
      created_at: Time.now,
      last_synced_at: Time.now,
      expires_at: Time.now + (90 * 24 * 60 * 60) # 90 days
    )

    requisition["link"]
  end
end
