class Warehouse < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :branch
  has_many :inventory_items, dependent: :restrict_with_error
  has_many :stock_movements, dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id }
  validates :active, inclusion: { in: [ true, false ] }
end
