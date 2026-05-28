class Purchase < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :supplier
  belongs_to :warehouse
  has_many :purchase_items, dependent: :destroy

  enum :status, { draft: 0, received: 1, voided: 2 }

  validates :purchase_number, :purchased_at, presence: true
  validates :purchase_number, uniqueness: { scope: :store_id }
end
