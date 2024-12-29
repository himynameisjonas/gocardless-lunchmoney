Sequel.migration do
  change do
    add_column :transactions, :transaction_data, String
  end
end
