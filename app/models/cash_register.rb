class CashRegister < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :branch
  has_many :cash_sessions, dependent: :restrict_with_error

  enum :status, { available: 0, in_use: 1, inactive: 2 }

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id }
end
