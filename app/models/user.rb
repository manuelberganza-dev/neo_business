class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable,
    :recoverable,
    :rememberable,
    :validatable,
    :jwt_authenticatable,
    jwt_revocation_strategy: self

  belongs_to :store
  belongs_to :branch, optional: true
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :auth_refresh_tokens, dependent: :destroy

  before_validation :ensure_jti, on: :create

  validates :full_name, presence: true

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end

  def has_role?(role_name)
    roles.exists?(name: role_name.to_s)
  end

  def permission_keys
    Permission.joins(roles: :users).where(users: { id: id }).distinct.pluck(:key)
  end

  private

  def ensure_jti
    self.jti ||= SecureRandom.uuid
  end
end
