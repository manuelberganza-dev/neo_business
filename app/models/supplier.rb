class Supplier < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :purchases, dependent: :restrict_with_error

  validates :name, presence: true
end
