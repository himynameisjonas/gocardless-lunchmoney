Sequel.migration do
  change do
    add_column :transactions, :external_id, String
  end
end
