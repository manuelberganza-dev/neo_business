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
        assert_broadcasts Realtime::Broadcaster.stream_name(@store, :pos), 1 do
          post "/api/v1/cash_sessions/open",
            params: {
              cash_session: {
                cash_register_id: @cash_register.id,
                opening_amount: "50.00"
              }
            },
            headers: @headers,
            as: :json
        end

        assert_response :created
        cash_session_id = response.parsed_body.fetch("id")
        assert_equal "in_use", @cash_register.reload.status

        assert_broadcasts Realtime::Broadcaster.stream_name(@store, :inventory), 1 do
          assert_broadcasts Realtime::Broadcaster.stream_name(@store, :sales), 2 do
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
          end
        end

        assert_response :created
        sale_id = response.parsed_body.dig("sale", "id")
        assert_equal "paid", response.parsed_body.dig("sale", "status")
        assert_equal 8.to_d, @inventory_item.reload.quantity
        ActsAsTenant.with_tenant(@store) do
          assert_equal(-2.to_d, StockMovement.sale.last.qty)
        end

        sale_number = response.parsed_body.dig("sale", "sale_number")

        get "/api/v1/sales?status=paid&sale_number=#{sale_number}&branch_id=#{@branch.id}&cash_session_id=#{cash_session_id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal [ sale_id ], response.parsed_body.fetch("sales").map { |sale| sale.fetch("id") }

        get "/api/v1/reports/daily_sales?branch_id=#{@branch.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "EFECTIVO", response.parsed_body.dig("payment_summary", 0, "method")

        get "/api/v1/reports/sales_by_hour?branch_id=#{@branch.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal 1, response.parsed_body.fetch("hours").length

        get "/api/v1/reports/payment_methods?branch_id=#{@branch.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "EFECTIVO", response.parsed_body.dig("payment_methods", 0, "method")

        get "/api/v1/cash_sessions/current?cash_register_id=#{@cash_register.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal cash_session_id, response.parsed_body.dig("cash_session", "id")
        assert_equal "EFECTIVO", response.parsed_body.dig("cash_session", "payment_summary", 0, "method")
        assert_equal "22.6", response.parsed_body.dig("cash_session", "payment_summary", 0, "amount").to_s

        get "/api/v1/cash_sessions?status=open&branch_id=#{@branch.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal [ cash_session_id ], response.parsed_body.fetch("cash_sessions").map { |session| session.fetch("id") }

        get "/api/v1/cash_sessions/#{cash_session_id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal cash_session_id, response.parsed_body.dig("cash_session", "id")

        post "/api/v1/cash_sessions/#{cash_session_id}/close",
          params: { cash_session: { closing_amount: "72.60" } },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "closed", response.parsed_body.fetch("status")
        assert_equal "available", @cash_register.reload.status
        assert_equal "EFECTIVO", response.parsed_body.dig("payment_summary", 0, "method")
        assert_equal "22.6", response.parsed_body.dig("payment_summary", 0, "amount").to_s

        assert_broadcasts Realtime::Broadcaster.stream_name(@store, :inventory), 1 do
          assert_broadcasts Realtime::Broadcaster.stream_name(@store, :sales), 2 do
            post "/api/v1/sales/#{sale_id}/void",
              params: { sale: { reason: "Error de cajero" } },
              headers: @headers,
              as: :json
          end
        end

        assert_response :success
        assert_equal "voided", response.parsed_body.dig("sale", "status")
        assert_equal 10.to_d, @inventory_item.reload.quantity
        ActsAsTenant.with_tenant(@store) do
          assert_equal 2.to_d, StockMovement.void.last.qty
        end
      end

      test "mobile scan returns stock warehouse and image fields" do
        post "/api/v1/mobile/scan_product",
          params: {
            scan: {
              barcode: @product.barcode,
              warehouse_id: @warehouse.id
            }
          },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal @product.id, response.parsed_body.dig("product", "id")
        assert_equal false, response.parsed_body.dig("product", "image_attached")
        assert_nil response.parsed_body.dig("product", "image_url")
        assert_equal "10.0", response.parsed_body.dig("stock", "total_quantity").to_s
        assert_equal @warehouse.id, response.parsed_body.dig("stock", "warehouse", "warehouse_id")
        assert_equal "Bodega", response.parsed_body.dig("stock", "warehouse", "warehouse_name")
      end
    end
  end
end
