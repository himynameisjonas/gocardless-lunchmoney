Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id
      foreign_key :account_id, :accounts
    end
  end
end
