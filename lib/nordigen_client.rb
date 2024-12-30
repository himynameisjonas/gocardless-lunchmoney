class NordigenClient
  def initialize
    @client = Nordigen::NordigenClient.new(
      secret_id: ENV.fetch("NORDIGEN_SECRET_ID"),
      secret_key: ENV.fetch("NORDIGEN_SECRET_KEY")
    )
    @client.generate_token
  end

  def list_institutions(country_code)
    @client.institution.get_institutions(country_code)
  end

  def create_requisition(institution_id)
    @client.init_session(
      institution_id: institution_id,
      redirect_url: "http://localhost:3000/callback",
      reference_id: SecureRandom.uuid
    )
  end

  def get_requisition(requisition_id)
    @client.requisition.get_requisition_by_id(requisition_id)
  end

  def get_account(account_id)
    @client.account(account_id)
  end

  def get_account_metadata(account_id)
    get_account(account_id).get_metadata
  end

  def get_account_details(account_id)
    get_account(account_id).get_details
  end

  def get_account_transactions(account_id)
    get_account(account_id).get_transactions
  end
end
