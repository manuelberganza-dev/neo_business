class Branch < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :users, dependent: :nullify
  has_many :warehouses, dependent: :restrict_with_error
  has_many :cash_registers, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error

  enum :status, { active: 0, inactive: 1 }

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id }
end
