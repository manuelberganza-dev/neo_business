class InventoryItem < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :product
  belongs_to :warehouse

  validates :quantity, :min_stock, numericality: true
  validates :product_id, uniqueness: { scope: [ :store_id, :warehouse_id ] }

  def low_stock?
    quantity <= min_stock
  end
end
