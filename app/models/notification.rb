class Notification < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :user, optional: true

  validates :event, :title, presence: true

  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end
end
