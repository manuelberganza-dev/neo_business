module Inventory
  class MovementService
    def initialize(store:, user:)
      @store = store
      @user = user
    end

    def call(product:, warehouse:, movement_type:, qty:, unit_cost: 0, reference: nil, notes: nil, allow_negative: false)
      decimal_qty = BigDecimal(qty.to_s)
      raise ApplicationError.new("Quantity cannot be zero", code: "invalid_quantity") if decimal_qty.zero?

      result = InventoryItem.transaction do
        item = locked_inventory_item(product, warehouse)
        new_quantity = item.quantity + decimal_qty

        if new_quantity.negative? && !allow_negative
          raise ApplicationError.new("Insufficient stock for #{product.name}", code: "insufficient_stock")
        end

        item.update!(quantity: new_quantity)

        movement = StockMovement.create!(
          store: @store,
          product: product,
          warehouse: warehouse,
          user: @user,
          movement_type: movement_type,
          qty: decimal_qty,
          unit_cost: unit_cost || 0,
          reference: reference,
          notes: notes,
          occurred_at: Time.current
        )

        [ movement, item ]
      end

      movement, item = result
      ActiveRecord.after_all_transactions_commit do
        broadcast_inventory_events(movement, item)
      end
      movement
    end

    private

    def broadcast_inventory_events(movement, item)
      payload = {
        product_id: movement.product_id,
        product_name: movement.product.name,
        warehouse_id: movement.warehouse_id,
        warehouse_name: movement.warehouse.name,
        movement_id: movement.id,
        movement_type: movement.movement_type,
        qty: movement.qty,
        quantity: item.quantity,
        min_stock: item.min_stock,
        low_stock: item.low_stock?
      }

      Realtime::Broadcaster.inventory(@store, :stock_updated, payload)
      Realtime::Broadcaster.inventory(@store, :low_stock, payload) if item.low_stock?
      Realtime::Broadcaster.inventory(@store, :adjustment_created, payload) if movement.adjustment?
    end

    def locked_inventory_item(product, warehouse)
      item = InventoryItem.lock.find_by(product: product, warehouse: warehouse)
      return item if item

      InventoryItem.create!(
        store: @store,
        product: product,
        warehouse: warehouse,
        quantity: 0,
        min_stock: 0
      )
    end
  end
end
