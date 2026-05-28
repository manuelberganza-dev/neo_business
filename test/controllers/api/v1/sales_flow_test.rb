require "test_helper"

module Api
  module V1
    class SalesFlowTest < ActionDispatch::IntegrationTest
      setup do
        @store = Store.create!(
          name: "POS Store",
          legal_name: "POS Store S.A. de C.V.",
          nit: "0614-030303-103-0",
          status: :active
        )

        ActsAsTenant.with_tenant(@store) do
          @branch = Branch.create!(store: @store, code: "MAIN", name: "Main", status: :active)
          @unit = Unit.create!(store: @store, code: "UND", name: "Unidad")
          @warehouse = Warehouse.create!(store: @store, branch: @branch, code: "BOD", name: "Bodega")
          @cash_register = CashRegister.create!(store: @store, branch: @branch, code: "CAJA", name: "Caja")
          @product = Product.create!(
            store: @store,
            unit: @unit,
            sku: "SKU-001",
            barcode: "750100000001",
            name: "Producto test",
            cost: 4,
            price: 10,
            tax_rate: 0.13
          )
          @inventory_item = InventoryItem.create!(
            store: @store,
            product: @product,
            warehouse: @warehouse,
            quantity: 10,
            min_stock: 2
          )
        end

        @user = User.create!(
          store: @store,
          branch: @branch,
          email: "pos@test.local",
          full_name: "POS User",
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

      test "opens cash session creates sale moves inventory voids sale and closes session" do
        post "/api/v1/cash_sessions/open",
          params: {
            cash_session: {
              cash_register_id: @cash_register.id,
              opening_amount: "50.00"
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        cash_session_id = response.parsed_body.fetch("id")
        assert_equal "in_use", @cash_register.reload.status

        post "/api/v1/sales",
          params: {
            sale: {
              branch_id: @branch.id,
              cash_session_id: cash_session_id,
              warehouse_id: @warehouse.id,
              items: [
                {
                  product_id: @product.id,
                  quantity: "2",
                  unit_price: "10.00"
                }
              ],
              payments: [
                {
                  method: "EFECTIVO",
                  amount: "22.60"
                }
              ]
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        sale_id = response.parsed_body.dig("sale", "id")
        assert_equal "paid", response.parsed_body.dig("sale", "status")
        assert_equal 8.to_d, @inventory_item.reload.quantity
        ActsAsTenant.with_tenant(@store) do
          assert_equal(-2.to_d, StockMovement.sale.last.qty)
        end

        post "/api/v1/sales/#{sale_id}/void",
          params: { sale: { reason: "Error de cajero" } },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "voided", response.parsed_body.dig("sale", "status")
        assert_equal 10.to_d, @inventory_item.reload.quantity
        ActsAsTenant.with_tenant(@store) do
          assert_equal 2.to_d, StockMovement.void.last.qty
        end

        post "/api/v1/cash_sessions/#{cash_session_id}/close",
          params: { cash_session: { closing_amount: "50.00" } },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "closed", response.parsed_body.fetch("status")
        assert_equal "available", @cash_register.reload.status
      end
    end
  end
end
