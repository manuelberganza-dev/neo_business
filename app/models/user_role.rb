class UserRole < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :user
  belongs_to :role

  validates :role_id, uniqueness: { scope: [ :store_id, :user_id ] }
end
