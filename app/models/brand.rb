class Brand < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :products, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :store_id }
end
