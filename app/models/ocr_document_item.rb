class OcrDocumentItem < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :ocr_document

  validates :quantity, :unit_price, :tax_rate, :total, numericality: { greater_than_or_equal_to: 0 }
end
