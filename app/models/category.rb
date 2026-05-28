class Category < ApplicationRecord
  acts_as_tenant :store

  belongs_to :store
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  has_many :products, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :store_id }
end
