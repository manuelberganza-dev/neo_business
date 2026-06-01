class OcrDocument < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :user, optional: true
  has_many :ocr_document_items, dependent: :destroy

  enum :status, { verified: 0 }

  validates :currency, presence: true
  validates :subtotal, :tax, :discount, :total, :confidence, numericality: { greater_than_or_equal_to: 0 }
end
