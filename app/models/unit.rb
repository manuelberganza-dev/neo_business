class Unit < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :products, dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id }
end
