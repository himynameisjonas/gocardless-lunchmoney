Sequel.migration do
  change do
    add_column :accounts, :owner_name, String
  end
end
