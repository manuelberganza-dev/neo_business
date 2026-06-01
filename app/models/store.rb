class Store < ApplicationRecord
  has_many :branches, dependent: :destroy
  has_many :users, dependent: :restrict_with_error
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :categories, dependent: :destroy
  has_many :units, dependent: :destroy
  has_many :brands, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :warehouses, dependent: :destroy
  has_many :ocr_documents, dependent: :destroy

  enum :status, { active: 0, inactive: 1, suspended: 2 }

  validates :name, :legal_name, :nit, presence: true
  validates :nit, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :nit, format: { with: /\A[0-9\-]{9,20}\z/ }
  validates :nrc, format: { with: /\A[0-9\-]{2,20}\z/ }, allow_blank: true
end
