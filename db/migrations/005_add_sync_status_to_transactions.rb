Sequel.migration do
  change do
    add_column :transactions, :synced_at, DateTime
    add_column :transactions, :error, String
  end
end
