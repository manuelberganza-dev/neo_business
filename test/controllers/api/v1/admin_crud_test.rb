require "test_helper"

module Api
  module V1
    class AdminCrudTest < ActionDispatch::IntegrationTest
      setup do
        @store = Store.create!(
          name: "Admin Store",
          legal_name: "Admin Store S.A. de C.V.",
          nit: "0614-040404-104-0",
          status: :active
        )

        ActsAsTenant.with_tenant(@store) do
          @branch = Branch.create!(store: @store, code: "MAIN", name: "Main", status: :active)
          @unit = Unit.create!(store: @store, code: "UND", name: "Unidad")
          @brand = Brand.create!(store: @store, name: "Marca")
          @category = Category.create!(store: @store, name: "General")
        end

        @user = User.create!(
          store: @store,
          branch: @branch,
          email: "admin-crud@test.local",
          full_name: "Admin CRUD",
          password: "password123",
          password_confirmation: "password123"
        )

        role = Role.create!(name: "admin")
        ActsAsTenant.with_tenant(@store) do
          UserRole.create!(store: @store, user: @user, role: role)
        end

        @headers = {
          "Authorization" => "Bearer #{Warden::JWTAuth::UserEncoder.new.call(@user, :user, nil).first}"
        }
      end

      teardown do
        ActsAsTenant.current_tenant = nil
      end

      test "creates filters updates and deactivates product" do
        post "/api/v1/products",
          params: {
            product: {
              category_id: @category.id,
              unit_id: @unit.id,
              brand_id: @brand.id,
              sku: "abc-001",
              barcode: "750100000777",
              name: "Café Molido",
              cost: "2.50",
              price: "4.00",
              tax_rate: "0.13"
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        product_id = response.parsed_body.dig("product", "id")
        assert_equal "ABC-001", response.parsed_body.dig("product", "sku")

        get "/api/v1/products?sku=ABC&barcode=750100000777&active=true",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal 1, response.parsed_body.fetch("products").length

        patch "/api/v1/products/#{product_id}",
          params: { product: { price: "4.50" } },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "4.5", response.parsed_body.dig("product", "price").to_s

        delete "/api/v1/products/#{product_id}", headers: @headers, as: :json

        assert_response :success
        assert_equal false, response.parsed_body.dig("product", "active")
      end

      test "creates user with role and lists permissions" do
        permission = Permission.create!(key: "products.read", description: "Read products")
        role = Role.create!(name: "catalog", description: "Catalog")
        role.permissions << permission

        post "/api/v1/users",
          params: {
            user: {
              branch_id: @branch.id,
              email: "seller@test.local",
              full_name: "Seller",
              password: "password123",
              password_confirmation: "password123",
              role_ids: [ role.id ]
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        assert_equal [ "catalog" ], response.parsed_body.dig("user", "roles").map { |item| item.fetch("name") }

        get "/api/v1/permissions", headers: @headers, as: :json

        assert_response :success
        assert_includes response.parsed_body.fetch("permissions").map { |item| item.fetch("key") }, "products.read"
      end

      test "lists only active warehouses by default and manages cash registers" do
        active_warehouse = nil
        inactive_warehouse = nil

        ActsAsTenant.with_tenant(@store) do
          active_warehouse = Warehouse.create!(store: @store, branch: @branch, code: "ACT", name: "Activa", active: true)
          inactive_warehouse = Warehouse.create!(store: @store, branch: @branch, code: "INA", name: "Inactiva", active: false)
        end

        get "/api/v1/warehouses", headers: @headers, as: :json

        assert_response :success
        warehouse_ids = response.parsed_body.fetch("warehouses").map { |item| item.fetch("id") }
        assert_includes warehouse_ids, active_warehouse.id
        assert_not_includes warehouse_ids, inactive_warehouse.id

        get "/api/v1/warehouses?include_inactive=true", headers: @headers, as: :json

        assert_response :success
        warehouse_ids = response.parsed_body.fetch("warehouses").map { |item| item.fetch("id") }
        assert_includes warehouse_ids, inactive_warehouse.id

        post "/api/v1/cash_registers",
          params: {
            cash_register: {
              branch_id: @branch.id,
              code: "CAJA-2",
              name: "Caja 2",
              status: "available"
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        assert_equal "CAJA-2", response.parsed_body.dig("cash_register", "code")
        assert_equal "available", response.parsed_body.dig("cash_register", "status")
      end
    end
  end
end
