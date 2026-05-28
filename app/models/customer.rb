class Customer < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  has_many :sales, dependent: :nullify

  enum :document_type, { dui: 0, nit: 1, passport: 2, nrc: 3, other: 4 }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :nit, format: { with: /\A[0-9\-]{9,20}\z/ }, allow_blank: true
  validates :nrc, format: { with: /\A[0-9\-]{2,20}\z/ }, allow_blank: true
  validates :document_number, format: { with: /\A[0-9A-Za-z\-]{2,30}\z/ }, allow_blank: true
end
