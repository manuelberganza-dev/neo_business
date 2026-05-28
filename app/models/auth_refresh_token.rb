class AuthRefreshToken < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :user

  validates :token_digest, :jti, :expires_at, presence: true
  validates :token_digest, :jti, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
end
