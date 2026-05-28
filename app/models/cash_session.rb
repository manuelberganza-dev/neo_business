class CashSession < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :cash_register
  belongs_to :user
  has_many :sales, dependent: :restrict_with_error

  enum :status, { open: 0, closed: 1, cancelled: 2 }

  validates :opening_amount, :opened_at, presence: true
end
