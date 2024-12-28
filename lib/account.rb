class Account < Sequel::Model
  many_to_one :requisition
end
