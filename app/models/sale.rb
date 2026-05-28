class Sale < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :branch
  belongs_to :cashier, class_name: "User"
  belongs_to :customer, optional: true
  belongs_to :cash_session
  has_many :sale_items, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_one :invoice, dependent: :destroy

  enum :status, { draft: 0, paid: 1, voided: 2, refunded: 3 }

  validates :sale_number, :sold_at, presence: true
  validates :sale_number, uniqueness: { scope: :store_id }
  validates :idempotency_key, uniqueness: { scope: :store_id }, allow_blank: true
end
