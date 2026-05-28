class PaymentMethod < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :payments, dependent: :nullify

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id }
end
