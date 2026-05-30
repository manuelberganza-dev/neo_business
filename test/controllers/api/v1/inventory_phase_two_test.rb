require "test_helper"

module Api
  module V1
    class InventoryPhaseTwoTest < ActionDispatch::IntegrationTest
      setup do
        @store = Store.create!(
          name: "Inventory Store",
          legal_name: "Inventory Store S.A. de C.V.",
          nit: "0614-050505-105-0",
          status: :active
        )

        ActsAsTenant.with_tenant(@store) do
          @branch = Branch.create!(store: @store, code: "MAIN", name: "Main", status: :active)
          @unit = Unit.create!(store: @store, code: "UND", name: "Unidad")
          @warehouse_a = Warehouse.create!(store: @store, branch: @branch, code: "A", name: "Bodega A")
          @warehouse_b = Warehouse.create!(store: @store, branch: @branch, code: "B", name: "Bodega B")
          @supplier = Supplier.create!(store: @store, name: "Proveedor Demo", nit: "0614-060606-106-0")
          @product = Product.create!(
            store: @store,
            unit: @unit,
            sku: "TR-001",
            barcode: "750100000888",
            name: "Transferible",
            cost: 3,
            price: 5
          )
          @item_a = InventoryItem.create!(store: @store, product: @product, warehouse: @warehouse_a, quantity: 10, min_stock: 2)
          @item_b = InventoryItem.create!(store: @store, product: @product, warehouse: @warehouse_b, quantity: 0, min_stock: 1)
        end

        @user = User.create!(
          store: @store,
          branch: @branch,
          email: "inventory@test.local",
          full_name: "Inventory User",
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

      test "updates min stock and transfers inventory between warehouses" do
        patch "/api/v1/inventory/#{@item_a.id}",
          params: { inventory_item: { min_stock: "5" } },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal 5.to_d, @item_a.reload.min_stock

        post "/api/v1/stock_movements/transfer",
          params: {
            transfer: {
              product_id: @product.id,
              from_warehouse_id: @warehouse_a.id,
              to_warehouse_id: @warehouse_b.id,
              qty: "3",
              notes: "Reabastecimiento sucursal"
            }
          },
          headers: @headers,
          as: :json

        assert_response :created
        assert_equal 7.to_d, @item_a.reload.quantity
        assert_equal 3.to_d, @item_b.reload.quantity

        get "/api/v1/inventory/products/#{@product.id}/kardex", headers: @headers, as: :json

        assert_response :success
        assert_equal 2, response.parsed_body.fetch("kardex").length
      end

      test "lists shows voids purchases and reads persistent notifications" do
        assert_broadcasts Realtime::Broadcaster.stream_name(@store, :notifications), 1 do
          post "/api/v1/purchases",
            params: {
              purchase: {
                supplier_id: @supplier.id,
                warehouse_id: @warehouse_a.id,
                invoice_number: "CCF-001",
                discount: "0.00",
                items: [
                  {
                    product_id: @product.id,
                    quantity: "4",
                    cost: "3.00",
                    tax_rate: "0.13"
                  }
                ]
              }
            },
            headers: @headers,
            as: :json
        end

        assert_response :created
        purchase_id = response.parsed_body.dig("purchase", "id")
        assert_equal 14.to_d, @item_a.reload.quantity

        get "/api/v1/purchases?status=received&supplier_id=#{@supplier.id}&warehouse_id=#{@warehouse_a.id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal [ purchase_id ], response.parsed_body.fetch("purchases").map { |purchase| purchase.fetch("id") }

        get "/api/v1/purchases/#{purchase_id}",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "Proveedor Demo", response.parsed_body.dig("purchase", "supplier_name")

        get "/api/v1/notifications?unread=true",
          headers: @headers,
          as: :json

        assert_response :success
        notification_id = response.parsed_body.fetch("notifications").first.fetch("id")
        assert_equal "purchase_received", response.parsed_body.fetch("notifications").first.fetch("event")

        patch "/api/v1/notifications/#{notification_id}/read",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal true, response.parsed_body.dig("notification", "read")

        assert_broadcasts Realtime::Broadcaster.stream_name(@store, :notifications), 1 do
          post "/api/v1/purchases/#{purchase_id}/void",
            params: { purchase: { reason: "Factura duplicada" } },
            headers: @headers,
            as: :json
        end

        assert_response :success
        assert_equal "voided", response.parsed_body.dig("purchase", "status")
        assert_equal 10.to_d, @item_a.reload.quantity

        patch "/api/v1/notifications/read_all?unread=true",
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal 1, response.parsed_body.fetch("read_count")
      end
    end
  end
end
