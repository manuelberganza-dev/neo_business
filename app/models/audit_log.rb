class AuditLog < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :user, optional: true

  validates :action, :entity, :occurred_at, presence: true
end
