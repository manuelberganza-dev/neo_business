class Supplier < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :purchases, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :nit, format: { with: /\A[0-9\-]{9,20}\z/ }, allow_blank: true
  validates :nrc, format: { with: /\A[0-9\-]{2,20}\z/ }, allow_blank: true
end
