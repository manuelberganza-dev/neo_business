class Payment < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :sale
  belongs_to :payment_method, optional: true

  enum :status, { received: 0, voided: 1 }

  validates :method, :paid_at, presence: true
  validates :amount, numericality: { greater_than: 0 }
end
