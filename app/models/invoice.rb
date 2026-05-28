class Invoice < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :sale

  enum :status, { draft: 0, issued: 1, rejected: 2, voided: 3, contingency: 4 }

  validates :doc_type, :environment, :emission_type, presence: true
  validates :sale_id, uniqueness: { scope: :store_id }
  validates :control_number, uniqueness: { scope: :store_id }, allow_blank: true
  validates :generation_code, uniqueness: { scope: :store_id }, allow_blank: true
end
