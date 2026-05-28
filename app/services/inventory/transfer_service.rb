module Inventory
  class TransferService
    def initialize(store:, user:)
      @store = store
      @user = user
      @movement_service = MovementService.new(store: store, user: user)
    end

    def call(product_id:, from_warehouse_id:, to_warehouse_id:, qty:, notes:)
      raise ApplicationError.new("Transfer reason is required", code: "transfer_reason_required") if notes.blank?
      raise ApplicationError.new("Warehouses must be different", code: "same_warehouse_transfer") if from_warehouse_id == to_warehouse_id

      StockMovement.transaction do
        product = Product.find(product_id)
        from_warehouse = Warehouse.find(from_warehouse_id)
        to_warehouse = Warehouse.find(to_warehouse_id)

        outgoing = @movement_service.call(
          product: product,
          warehouse: from_warehouse,
          movement_type: :transfer_out,
          qty: -BigDecimal(qty.to_s),
          unit_cost: product.cost,
          notes: notes
        )

        incoming = @movement_service.call(
          product: product,
          warehouse: to_warehouse,
          movement_type: :transfer_in,
          qty: qty,
          unit_cost: product.cost,
          notes: notes,
          allow_negative: true
        )

        audit!("inventory.transfer", product, {
          from_warehouse_id: from_warehouse.id,
          to_warehouse_id: to_warehouse.id,
          qty: qty,
          outgoing_movement_id: outgoing.id,
          incoming_movement_id: incoming.id
        })

        [ outgoing, incoming ]
      end
    end

    private

    def audit!(action, record, metadata = {})
      AuditLog.create!(
        store: @store,
        user: @user,
        action: action,
        entity: record.class.name,
        entity_id: record.id,
        metadata: metadata,
        occurred_at: Time.current
      )
    end
  end
end
