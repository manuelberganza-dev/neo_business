# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_28_204437) do
  create_table "audit_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "entity", null: false
    t.bigint "entity_id"
    t.string "ip_address"
    t.json "metadata"
    t.datetime "occurred_at", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id"
    t.index ["entity", "entity_id"], name: "index_audit_logs_on_entity_and_entity_id"
    t.index ["store_id", "action"], name: "index_audit_logs_on_store_id_and_action"
    t.index ["store_id", "occurred_at"], name: "index_audit_logs_on_store_id_and_occurred_at"
    t.index ["store_id"], name: "index_audit_logs_on_store_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "auth_refresh_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id"
    t.string "device_name"
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.string "jti", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.bigint "store_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.index ["jti"], name: "index_auth_refresh_tokens_on_jti", unique: true
    t.index ["store_id", "user_id"], name: "index_auth_refresh_tokens_on_store_id_and_user_id"
    t.index ["store_id"], name: "index_auth_refresh_tokens_on_store_id"
    t.index ["token_digest"], name: "index_auth_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_auth_refresh_tokens_on_user_id"
  end

  create_table "branches", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "address"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "establishment_code"
    t.boolean "is_main", default: false, null: false
    t.string "name", null: false
    t.string "phone"
    t.string "point_of_sale_code"
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_branches_on_store_id_and_code", unique: true
    t.index ["store_id", "is_main"], name: "index_branches_on_store_id_and_is_main"
    t.index ["store_id"], name: "index_branches_on_store_id"
  end

  create_table "brands", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "name"], name: "index_brands_on_store_id_and_name", unique: true
    t.index ["store_id"], name: "index_brands_on_store_id"
  end

  create_table "cash_registers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_cash_registers_on_branch_id"
    t.index ["store_id", "branch_id"], name: "index_cash_registers_on_store_id_and_branch_id"
    t.index ["store_id", "code"], name: "index_cash_registers_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_cash_registers_on_store_id"
  end

  create_table "cash_sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "cash_register_id", null: false
    t.datetime "closed_at"
    t.decimal "closing_amount", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.decimal "difference_amount", precision: 15, scale: 4
    t.decimal "expected_amount", precision: 15, scale: 4
    t.datetime "opened_at", null: false
    t.decimal "opening_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["cash_register_id"], name: "index_cash_sessions_on_cash_register_id"
    t.index ["store_id", "cash_register_id", "status"], name: "idx_on_store_id_cash_register_id_status_7ed3347ff0"
    t.index ["store_id", "user_id"], name: "index_cash_sessions_on_store_id_and_user_id"
    t.index ["store_id"], name: "index_cash_sessions_on_store_id"
    t.index ["user_id"], name: "index_cash_sessions_on_user_id"
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["store_id", "active"], name: "index_categories_on_store_id_and_active"
    t.index ["store_id", "name"], name: "index_categories_on_store_id_and_name", unique: true
    t.index ["store_id"], name: "index_categories_on_store_id"
  end

  create_table "customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.string "document_number"
    t.integer "document_type", default: 0, null: false
    t.string "email"
    t.string "name", null: false
    t.string "nit"
    t.string "nrc"
    t.string "phone"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "document_type", "document_number"], name: "idx_on_store_id_document_type_document_number_005f823280"
    t.index ["store_id", "nit"], name: "index_customers_on_store_id_and_nit"
    t.index ["store_id", "nrc"], name: "index_customers_on_store_id_and_nrc"
    t.index ["store_id"], name: "index_customers_on_store_id"
  end

  create_table "inventory_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "min_stock", precision: 15, scale: 3, default: "0.0", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 15, scale: 3, default: "0.0", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["product_id"], name: "index_inventory_items_on_product_id"
    t.index ["store_id", "product_id", "warehouse_id"], name: "idx_on_store_id_product_id_warehouse_id_1f8c589258", unique: true
    t.index ["store_id", "warehouse_id"], name: "index_inventory_items_on_store_id_and_warehouse_id"
    t.index ["store_id"], name: "index_inventory_items_on_store_id"
    t.index ["warehouse_id"], name: "index_inventory_items_on_warehouse_id"
  end

  create_table "invoices", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "control_number"
    t.datetime "created_at", null: false
    t.string "customer_document_number"
    t.string "customer_document_type"
    t.string "customer_email"
    t.string "customer_name"
    t.string "customer_nit"
    t.string "customer_nrc"
    t.decimal "discount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "doc_type", null: false
    t.string "emission_type", default: "normal", null: false
    t.string "environment", default: "test", null: false
    t.string "generation_code"
    t.datetime "issued_at"
    t.json "payload"
    t.string "reception_stamp"
    t.json "response_payload"
    t.bigint "sale_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.decimal "subtotal", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "tax", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at"
    t.index ["sale_id"], name: "index_invoices_on_sale_id"
    t.index ["store_id", "control_number"], name: "index_invoices_on_store_id_and_control_number", unique: true
    t.index ["store_id", "generation_code"], name: "index_invoices_on_store_id_and_generation_code", unique: true
    t.index ["store_id", "sale_id"], name: "index_invoices_on_store_id_and_sale_id", unique: true
    t.index ["store_id", "status"], name: "index_invoices_on_store_id_and_status"
    t.index ["store_id"], name: "index_invoices_on_store_id"
  end

  create_table "payment_methods", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_payment_methods_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_payment_methods_on_store_id"
  end

  create_table "payments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "method", null: false
    t.datetime "paid_at", null: false
    t.bigint "payment_method_id"
    t.string "reference"
    t.bigint "sale_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_payments_on_payment_method_id"
    t.index ["sale_id"], name: "index_payments_on_sale_id"
    t.index ["store_id", "method"], name: "index_payments_on_store_id_and_method"
    t.index ["store_id", "sale_id"], name: "index_payments_on_store_id_and_sale_id"
    t.index ["store_id"], name: "index_payments_on_store_id"
  end

  create_table "permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "products", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "barcode"
    t.bigint "brand_id"
    t.bigint "category_id"
    t.decimal "cost", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "price", precision: 15, scale: 4, default: "0.0", null: false
    t.string "sku", null: false
    t.bigint "store_id", null: false
    t.decimal "tax_rate", precision: 6, scale: 4, default: "0.13", null: false
    t.boolean "track_inventory", default: true, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["store_id", "active"], name: "index_products_on_store_id_and_active"
    t.index ["store_id", "barcode"], name: "index_products_on_store_id_and_barcode", unique: true
    t.index ["store_id", "name"], name: "index_products_on_store_id_and_name"
    t.index ["store_id", "sku"], name: "index_products_on_store_id_and_sku", unique: true
    t.index ["store_id"], name: "index_products_on_store_id"
    t.index ["unit_id"], name: "index_products_on_unit_id"
  end

  create_table "purchase_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "cost", precision: 15, scale: 4, null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "purchase_id", null: false
    t.decimal "quantity", precision: 15, scale: 3, null: false
    t.bigint "store_id", null: false
    t.decimal "tax", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "tax_rate", precision: 6, scale: 4, default: "0.13", null: false
    t.decimal "total", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_items_on_product_id"
    t.index ["purchase_id"], name: "index_purchase_items_on_purchase_id"
    t.index ["store_id", "product_id"], name: "index_purchase_items_on_store_id_and_product_id"
    t.index ["store_id", "purchase_id"], name: "index_purchase_items_on_store_id_and_purchase_id"
    t.index ["store_id"], name: "index_purchase_items_on_store_id"
  end

  create_table "purchases", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "discount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "document_type"
    t.string "invoice_number"
    t.string "purchase_number", null: false
    t.datetime "purchased_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.decimal "subtotal", precision: 15, scale: 4, default: "0.0", null: false
    t.bigint "supplier_id", null: false
    t.decimal "tax", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["store_id", "purchase_number"], name: "index_purchases_on_store_id_and_purchase_number", unique: true
    t.index ["store_id", "supplier_id"], name: "index_purchases_on_store_id_and_supplier_id"
    t.index ["store_id", "warehouse_id"], name: "index_purchases_on_store_id_and_warehouse_id"
    t.index ["store_id"], name: "index_purchases_on_store_id"
    t.index ["supplier_id"], name: "index_purchases_on_supplier_id"
    t.index ["warehouse_id"], name: "index_purchases_on_warehouse_id"
  end

  create_table "role_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.boolean "system_role", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sale_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "discount", precision: 15, scale: 4, default: "0.0", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 15, scale: 3, null: false
    t.bigint "sale_id", null: false
    t.bigint "store_id", null: false
    t.decimal "tax", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "tax_rate", precision: 6, scale: 4, default: "0.13", null: false
    t.decimal "total", precision: 15, scale: 4, null: false
    t.decimal "unit_cost", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "unit_price", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_sale_items_on_product_id"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
    t.index ["store_id", "product_id"], name: "index_sale_items_on_store_id_and_product_id"
    t.index ["store_id", "sale_id"], name: "index_sale_items_on_store_id_and_sale_id"
    t.index ["store_id"], name: "index_sale_items_on_store_id"
  end

  create_table "sales", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.bigint "cash_session_id", null: false
    t.bigint "cashier_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.decimal "discount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "idempotency_key"
    t.string "sale_number", null: false
    t.datetime "sold_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "store_id", null: false
    t.decimal "subtotal", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "tax", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.text "void_reason"
    t.datetime "voided_at"
    t.index ["branch_id"], name: "index_sales_on_branch_id"
    t.index ["cash_session_id"], name: "index_sales_on_cash_session_id"
    t.index ["cashier_id"], name: "index_sales_on_cashier_id"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
    t.index ["store_id", "branch_id", "sold_at"], name: "index_sales_on_store_id_and_branch_id_and_sold_at"
    t.index ["store_id", "idempotency_key"], name: "index_sales_on_store_id_and_idempotency_key", unique: true
    t.index ["store_id", "sale_number"], name: "index_sales_on_store_id_and_sale_number", unique: true
    t.index ["store_id", "status"], name: "index_sales_on_store_id_and_status"
    t.index ["store_id"], name: "index_sales_on_store_id"
  end

  create_table "stock_movements", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "movement_type", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.bigint "product_id", null: false
    t.decimal "qty", precision: 15, scale: 3, null: false
    t.bigint "reference_id"
    t.string "reference_type"
    t.bigint "store_id", null: false
    t.decimal "unit_cost", precision: 15, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "warehouse_id", null: false
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["reference_type", "reference_id"], name: "index_stock_movements_on_reference_type_and_reference_id"
    t.index ["store_id", "occurred_at"], name: "index_stock_movements_on_store_id_and_occurred_at"
    t.index ["store_id", "product_id", "warehouse_id"], name: "idx_on_store_id_product_id_warehouse_id_9bfc4f1fbd"
    t.index ["store_id"], name: "index_stock_movements_on_store_id"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
    t.index ["warehouse_id"], name: "index_stock_movements_on_warehouse_id"
  end

  create_table "stores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "address"
    t.string "commercial_name"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "economic_activity"
    t.string "economic_activity_code"
    t.string "email"
    t.string "legal_name", null: false
    t.string "municipality"
    t.string "name", null: false
    t.string "nit", null: false
    t.string "nrc"
    t.string "phone"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["nit"], name: "index_stores_on_nit", unique: true
    t.index ["nrc"], name: "index_stores_on_nrc"
    t.index ["status"], name: "index_stores_on_status"
  end

  create_table "suppliers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "nit"
    t.string "nrc"
    t.string "phone"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "name"], name: "index_suppliers_on_store_id_and_name"
    t.index ["store_id", "nit"], name: "index_suppliers_on_store_id_and_nit"
    t.index ["store_id", "nrc"], name: "index_suppliers_on_store_id_and_nrc"
    t.index ["store_id"], name: "index_suppliers_on_store_id"
  end

  create_table "units", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_units_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_units_on_store_id"
  end

  create_table "user_roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["store_id", "user_id", "role_id"], name: "index_user_roles_on_store_id_and_user_id_and_role_id", unique: true
    t.index ["store_id"], name: "index_user_roles_on_store_id"
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name", null: false
    t.string "jti", null: false
    t.datetime "last_sign_in_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_users_on_branch_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["store_id", "active"], name: "index_users_on_store_id_and_active"
    t.index ["store_id"], name: "index_users_on_store_id"
  end

  create_table "warehouses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_warehouses_on_branch_id"
    t.index ["store_id", "branch_id"], name: "index_warehouses_on_store_id_and_branch_id"
    t.index ["store_id", "code"], name: "index_warehouses_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_warehouses_on_store_id"
  end

  add_foreign_key "audit_logs", "stores"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "auth_refresh_tokens", "stores"
  add_foreign_key "auth_refresh_tokens", "users"
  add_foreign_key "branches", "stores"
  add_foreign_key "brands", "stores"
  add_foreign_key "cash_registers", "branches"
  add_foreign_key "cash_registers", "stores"
  add_foreign_key "cash_sessions", "cash_registers"
  add_foreign_key "cash_sessions", "stores"
  add_foreign_key "cash_sessions", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "stores"
  add_foreign_key "customers", "stores"
  add_foreign_key "inventory_items", "products"
  add_foreign_key "inventory_items", "stores"
  add_foreign_key "inventory_items", "warehouses"
  add_foreign_key "invoices", "sales"
  add_foreign_key "invoices", "stores"
  add_foreign_key "payment_methods", "stores"
  add_foreign_key "payments", "payment_methods"
  add_foreign_key "payments", "sales"
  add_foreign_key "payments", "stores"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "stores"
  add_foreign_key "products", "units"
  add_foreign_key "purchase_items", "products"
  add_foreign_key "purchase_items", "purchases"
  add_foreign_key "purchase_items", "stores"
  add_foreign_key "purchases", "stores"
  add_foreign_key "purchases", "suppliers"
  add_foreign_key "purchases", "warehouses"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "sale_items", "products"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sale_items", "stores"
  add_foreign_key "sales", "branches"
  add_foreign_key "sales", "cash_sessions"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "stores"
  add_foreign_key "sales", "users", column: "cashier_id"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "stores"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "stock_movements", "warehouses"
  add_foreign_key "suppliers", "stores"
  add_foreign_key "units", "stores"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "stores"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "branches"
  add_foreign_key "users", "stores"
  add_foreign_key "warehouses", "branches"
  add_foreign_key "warehouses", "stores"
end
