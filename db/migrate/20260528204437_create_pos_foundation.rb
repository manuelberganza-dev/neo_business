class CreatePosFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :legal_name, null: false
      t.string :commercial_name
      t.string :nit, null: false
      t.string :nrc
      t.string :economic_activity_code
      t.string :economic_activity
      t.string :email
      t.string :phone
      t.string :department
      t.string :municipality
      t.text :address
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :stores, :nit, unique: true
    add_index :stores, :nrc
    add_index :stores, :status

    create_table :branches do |t|
      t.references :store, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :address
      t.string :phone
      t.string :establishment_code
      t.string :point_of_sale_code
      t.boolean :is_main, null: false, default: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :branches, [ :store_id, :code ], unique: true
    add_index :branches, [ :store_id, :is_main ]

    create_table :users do |t|
      t.references :store, null: false, foreign_key: true
      t.references :branch, null: true, foreign_key: true
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :jti, null: false
      t.string :full_name, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_sign_in_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :jti, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, [ :store_id, :active ]

    create_table :auth_refresh_tokens do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :jti, null: false
      t.string :device_id
      t.string :device_name
      t.string :ip_address
      t.text :user_agent
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :auth_refresh_tokens, :token_digest, unique: true
    add_index :auth_refresh_tokens, :jti, unique: true
    add_index :auth_refresh_tokens, [ :store_id, :user_id ]

    create_table :roles do |t|
      t.string :name, null: false
      t.string :description
      t.boolean :system_role, null: false, default: true

      t.timestamps
    end

    add_index :roles, :name, unique: true

    create_table :permissions do |t|
      t.string :key, null: false
      t.string :description

      t.timestamps
    end

    add_index :permissions, :key, unique: true

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true

      t.timestamps
    end

    add_index :role_permissions, [ :role_id, :permission_id ], unique: true

    create_table :user_roles do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_roles, [ :store_id, :user_id, :role_id ], unique: true

    create_table :categories do |t|
      t.references :store, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :categories }
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :categories, [ :store_id, :name ], unique: true
    add_index :categories, [ :store_id, :active ]

    create_table :units do |t|
      t.references :store, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :units, [ :store_id, :code ], unique: true

    create_table :brands do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :brands, [ :store_id, :name ], unique: true

    create_table :payment_methods do |t|
      t.references :store, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :payment_methods, [ :store_id, :code ], unique: true

    create_table :products do |t|
      t.references :store, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.references :unit, null: false, foreign_key: true
      t.references :brand, null: true, foreign_key: true
      t.string :sku, null: false
      t.string :barcode
      t.string :name, null: false
      t.text :description
      t.decimal :cost, precision: 15, scale: 4, null: false, default: 0
      t.decimal :price, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax_rate, precision: 6, scale: 4, null: false, default: 0.13
      t.boolean :track_inventory, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, [ :store_id, :sku ], unique: true
    add_index :products, [ :store_id, :barcode ], unique: true
    add_index :products, [ :store_id, :name ]
    add_index :products, [ :store_id, :active ]

    create_table :warehouses do |t|
      t.references :store, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :warehouses, [ :store_id, :code ], unique: true
    add_index :warehouses, [ :store_id, :branch_id ]

    create_table :inventory_items do |t|
      t.references :store, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.decimal :quantity, precision: 15, scale: 3, null: false, default: 0
      t.decimal :min_stock, precision: 15, scale: 3, null: false, default: 0

      t.timestamps
    end

    add_index :inventory_items, [ :store_id, :product_id, :warehouse_id ], unique: true
    add_index :inventory_items, [ :store_id, :warehouse_id ]

    create_table :stock_movements do |t|
      t.references :store, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.integer :movement_type, null: false
      t.decimal :qty, precision: 15, scale: 3, null: false
      t.decimal :unit_cost, precision: 15, scale: 4, null: false, default: 0
      t.string :reference_type
      t.bigint :reference_id
      t.text :notes
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :stock_movements, [ :store_id, :product_id, :warehouse_id ]
    add_index :stock_movements, [ :reference_type, :reference_id ]
    add_index :stock_movements, [ :store_id, :occurred_at ]

    create_table :customers do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :document_type, null: false, default: 0
      t.string :document_number
      t.string :nit
      t.string :nrc
      t.string :email
      t.string :phone
      t.text :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :customers, [ :store_id, :document_type, :document_number ]
    add_index :customers, [ :store_id, :nit ]
    add_index :customers, [ :store_id, :nrc ]

    create_table :suppliers do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :nit
      t.string :nrc
      t.string :email
      t.string :phone
      t.text :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :suppliers, [ :store_id, :name ]
    add_index :suppliers, [ :store_id, :nit ]
    add_index :suppliers, [ :store_id, :nrc ]

    create_table :cash_registers do |t|
      t.references :store, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :cash_registers, [ :store_id, :code ], unique: true
    add_index :cash_registers, [ :store_id, :branch_id ]

    create_table :cash_sessions do |t|
      t.references :store, null: false, foreign_key: true
      t.references :cash_register, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :opening_amount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :closing_amount, precision: 15, scale: 4
      t.decimal :expected_amount, precision: 15, scale: 4
      t.decimal :difference_amount, precision: 15, scale: 4
      t.integer :status, null: false, default: 0
      t.datetime :opened_at, null: false
      t.datetime :closed_at

      t.timestamps
    end

    add_index :cash_sessions, [ :store_id, :cash_register_id, :status ]
    add_index :cash_sessions, [ :store_id, :user_id ]

    create_table :sales do |t|
      t.references :store, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :cashier, null: false, foreign_key: { to_table: :users }
      t.references :customer, null: true, foreign_key: true
      t.references :cash_session, null: false, foreign_key: true
      t.string :sale_number, null: false
      t.string :idempotency_key
      t.decimal :subtotal, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :sold_at, null: false
      t.datetime :voided_at
      t.text :void_reason

      t.timestamps
    end

    add_index :sales, [ :store_id, :sale_number ], unique: true
    add_index :sales, [ :store_id, :idempotency_key ], unique: true
    add_index :sales, [ :store_id, :branch_id, :sold_at ]
    add_index :sales, [ :store_id, :status ]

    create_table :sale_items do |t|
      t.references :store, null: false, foreign_key: true
      t.references :sale, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 15, scale: 3, null: false
      t.decimal :unit_price, precision: 15, scale: 4, null: false
      t.decimal :unit_cost, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax_rate, precision: 6, scale: 4, null: false, default: 0.13
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false

      t.timestamps
    end

    add_index :sale_items, [ :store_id, :sale_id ]
    add_index :sale_items, [ :store_id, :product_id ]

    create_table :payments do |t|
      t.references :store, null: false, foreign_key: true
      t.references :sale, null: false, foreign_key: true
      t.references :payment_method, null: true, foreign_key: true
      t.string :method, null: false
      t.decimal :amount, precision: 15, scale: 4, null: false
      t.string :reference
      t.integer :status, null: false, default: 0
      t.datetime :paid_at, null: false

      t.timestamps
    end

    add_index :payments, [ :store_id, :sale_id ]
    add_index :payments, [ :store_id, :method ]

    create_table :invoices do |t|
      t.references :store, null: false, foreign_key: true
      t.references :sale, null: false, foreign_key: true
      t.string :doc_type, null: false
      t.string :control_number
      t.string :generation_code
      t.string :reception_stamp
      t.string :environment, null: false, default: "test"
      t.string :emission_type, null: false, default: "normal"
      t.string :customer_name
      t.string :customer_document_type
      t.string :customer_document_number
      t.string :customer_nit
      t.string :customer_nrc
      t.string :customer_email
      t.decimal :subtotal, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :issued_at
      t.datetime :voided_at
      t.json :payload
      t.json :response_payload

      t.timestamps
    end

    add_index :invoices, [ :store_id, :sale_id ], unique: true
    add_index :invoices, [ :store_id, :control_number ], unique: true
    add_index :invoices, [ :store_id, :generation_code ], unique: true
    add_index :invoices, [ :store_id, :status ]

    create_table :purchases do |t|
      t.references :store, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.string :purchase_number, null: false
      t.string :document_type
      t.string :invoice_number
      t.decimal :subtotal, precision: 15, scale: 4, null: false, default: 0
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :purchased_at, null: false

      t.timestamps
    end

    add_index :purchases, [ :store_id, :purchase_number ], unique: true
    add_index :purchases, [ :store_id, :supplier_id ]
    add_index :purchases, [ :store_id, :warehouse_id ]

    create_table :purchase_items do |t|
      t.references :store, null: false, foreign_key: true
      t.references :purchase, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 15, scale: 3, null: false
      t.decimal :cost, precision: 15, scale: 4, null: false
      t.decimal :tax_rate, precision: 6, scale: 4, null: false, default: 0.13
      t.decimal :tax, precision: 15, scale: 4, null: false, default: 0
      t.decimal :total, precision: 15, scale: 4, null: false

      t.timestamps
    end

    add_index :purchase_items, [ :store_id, :purchase_id ]
    add_index :purchase_items, [ :store_id, :product_id ]

    create_table :audit_logs do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.string :entity, null: false
      t.bigint :entity_id
      t.json :metadata
      t.string :ip_address
      t.text :user_agent
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :audit_logs, [ :store_id, :action ]
    add_index :audit_logs, [ :entity, :entity_id ]
    add_index :audit_logs, [ :store_id, :occurred_at ]
  end
end
