class PurchaseItem < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :purchase
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }
  validates :cost, :tax_rate, :tax, :total, numericality: { greater_than_or_equal_to: 0 }
end
