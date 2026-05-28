class Product < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :category, optional: true
  belongs_to :unit
  belongs_to :brand, optional: true
  has_many :inventory_items, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error
  has_one_attached :image

  validates :sku, :name, presence: true
  validates :sku, uniqueness: { scope: :store_id }
  validates :barcode, uniqueness: { scope: :store_id }, allow_blank: true
  validates :cost, :price, :tax_rate, numericality: { greater_than_or_equal_to: 0 }
end
