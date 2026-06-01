class CreateOcrDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :ocr_documents do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :document_type
      t.string :document_number
      t.string :control_number
      t.string :generation_code
      t.datetime :issued_at
      t.string :supplier_name
      t.string :supplier_nit
      t.string :supplier_nrc
      t.string :supplier_activity
      t.text :supplier_address
      t.string :customer_name
      t.string :customer_nit
      t.string :customer_nrc
      t.string :currency, null: false, default: "USD"
      t.decimal :subtotal, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false, default: 0
      t.decimal :confidence, precision: 5, scale: 4, null: false, default: 0
      t.json :warnings
      t.json :raw_response
      t.string :photo_path
      t.integer :status, null: false, default: 0
      t.datetime :verified_at

      t.timestamps
    end

    add_index :ocr_documents, [ :store_id, :document_type, :document_number ]
    add_index :ocr_documents, [ :store_id, :generation_code ]
    add_index :ocr_documents, [ :store_id, :status ]

    create_table :ocr_document_items do |t|
      t.references :store, null: false, foreign_key: true
      t.references :ocr_document, null: false, foreign_key: true
      t.text :description
      t.decimal :quantity, precision: 15, scale: 3, null: false, default: 0
      t.decimal :unit_price, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax_rate, precision: 6, scale: 4, null: false, default: 0.13
      t.decimal :total, precision: 15, scale: 4, null: false, default: 0

      t.timestamps
    end

    add_index :ocr_document_items, [ :store_id, :ocr_document_id ]
  end
end
