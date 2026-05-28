class Customer < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :sales, dependent: :nullify

  enum :document_type, { dui: 0, nit: 1, passport: 2, nrc: 3, other: 4 }

  validates :name, presence: true
end
