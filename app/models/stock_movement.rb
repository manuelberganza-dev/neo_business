class StockMovement < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :product
  belongs_to :warehouse
  belongs_to :user, optional: true
  belongs_to :reference, polymorphic: true, optional: true

  enum :movement_type, {
    purchase: 0,
    sale: 1,
    adjustment: 2,
    transfer_in: 3,
    transfer_out: 4,
    void: 5,
    return: 6
  }

  validates :movement_type, :qty, :occurred_at, presence: true
end
