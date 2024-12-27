Sequel.migration do
  change do
    create_table(:requisitions) do
      primary_key :id
      String :requisition_id, null: false
      String :status
      String :institution_id
      DateTime :created_at
      DateTime :last_synced_at
      DateTime :expires_at
    end

    create_table(:accounts) do
      primary_key :id
      foreign_key :requisition_id, :requisitions
      String :account_id, null: false
      String :lunch_money_id
      String :name
      String :iban
      String :status
      DateTime :last_synced_at
    end
  end
end
