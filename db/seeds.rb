permission_keys = %w[
  stores.read stores.write
  branches.read branches.write
  users.read users.write
  roles.read roles.write
  categories.read categories.write
  units.read units.write
  brands.read brands.write
  payment_methods.read payment_methods.write
  products.read products.write
  warehouses.read warehouses.write
  inventory_items.read inventory_items.write
  stock_movements.read stock_movements.write
  customers.read customers.write
  suppliers.read suppliers.write
  cash_registers.read cash_registers.write
  cash_sessions.read cash_sessions.write
  sales.read sales.write
  payments.read payments.write
  invoices.read invoices.write
  purchases.read purchases.write
  reports.read
  audit_logs.read
]

permissions = permission_keys.index_with do |key|
  Permission.find_or_create_by!(key: key) do |permission|
    permission.description = key.tr(".", " ").humanize
  end
end

role_permissions = {
  "admin" => permission_keys,
  "manager" => permission_keys - [ "stores.write" ],
  "cajero" => %w[
    products.read inventory_items.read customers.read customers.write
    cash_sessions.read cash_sessions.write sales.read sales.write
    payments.read payments.write invoices.read invoices.write
  ],
  "bodeguero" => %w[
    products.read products.write warehouses.read inventory_items.read
    inventory_items.write stock_movements.read stock_movements.write
    suppliers.read suppliers.write purchases.read purchases.write
  ]
}

role_permissions.each do |role_name, keys|
  role = Role.find_or_create_by!(name: role_name) do |record|
    record.description = role_name.humanize
  end

  keys.each do |key|
    RolePermission.find_or_create_by!(role: role, permission: permissions.fetch(key))
  end
end

if Rails.env.local?
  store = Store.find_or_create_by!(nit: "0614-010101-101-0") do |record|
    record.name = "Neo Business Demo"
    record.legal_name = "Neo Business Demo S.A. de C.V."
    record.commercial_name = "Neo Business"
    record.nrc = "123456-7"
    record.economic_activity_code = "46900"
    record.economic_activity = "Venta al por mayor no especializada"
    record.email = "admin@example.com"
    record.phone = "2222-2222"
    record.department = "San Salvador"
    record.municipality = "San Salvador Centro"
    record.address = "San Salvador, El Salvador"
    record.status = :active
  end

  ActsAsTenant.with_tenant(store) do
    branch = Branch.find_or_create_by!(store: store, code: "MATRIZ") do |record|
      record.name = "Casa matriz"
      record.address = store.address
      record.phone = store.phone
      record.establishment_code = "0001"
      record.point_of_sale_code = "0001"
      record.is_main = true
      record.status = :active
    end

    unit = Unit.find_or_create_by!(store: store, code: "UND") do |record|
      record.name = "Unidad"
    end

    %w[EFECTIVO TARJETA TRANSFERENCIA].each do |code|
      PaymentMethod.find_or_create_by!(store: store, code: code) do |record|
        record.name = code.humanize
      end
    end

    Warehouse.find_or_create_by!(store: store, branch: branch, code: "BOD-MATRIZ") do |record|
      record.name = "Bodega matriz"
    end

    CashRegister.find_or_create_by!(store: store, branch: branch, code: "CAJA-1") do |record|
      record.name = "Caja 1"
      record.status = :available
    end

    admin = User.find_or_create_by!(email: ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com")) do |record|
      record.store = store
      record.branch = branch
      record.full_name = "Administrador Demo"
      record.password = ENV.fetch("SEED_ADMIN_PASSWORD", "password123")
      record.password_confirmation = record.password
      record.active = true
    end

    UserRole.find_or_create_by!(store: store, user: admin, role: Role.find_by!(name: "admin"))

    Category.find_or_create_by!(store: store, name: "General")
    Brand.find_or_create_by!(store: store, name: "Generica")

    puts "Seed local listo. Admin: #{admin.email} / #{ENV.fetch("SEED_ADMIN_PASSWORD", "password123")}; unidad base: #{unit.code}"
  end
end
