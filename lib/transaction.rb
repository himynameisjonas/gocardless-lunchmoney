class Transaction < Sequel::Model
  many_to_one :account

  def data=(hash)
    self[:transaction_data] = JSON.dump(hash)
  end

  def data
    self[:transaction_data] ? JSON.parse(self[:transaction_data]) : {}
  end
end
