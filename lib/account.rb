class Account < Sequel::Model
  many_to_one :requisition
  one_to_many :transactions
end
