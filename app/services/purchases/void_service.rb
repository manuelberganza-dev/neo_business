module Purchases
  class VoidService
    def initialize(store:, user:)
      @store = store
      @user = user
      @inventory = Inventory::MovementService.new(store: store, user: user)
    end

    def call(purchase_id:, reason:)
      purchase = Purchase.transaction do
        purchase = Purchase.lock.includes(:purchase_items, :warehouse).find(purchase_id)
        ensure_same_store!(purchase)
        ensure_received!(purchase)

        purchase.purchase_items.each do |item|
          @inventory.call(
            product: item.product,
            warehouse: purchase.warehouse,
            movement_type: :void,
            qty: -item.quantity,
            unit_cost: item.cost,
            reference: purchase,
            notes: "Purchase void: #{reason}",
            allow_negative: false
          )
        end

        purchase.update!(status: :voided)
        audit!("purchase.void", purchase, reason: reason)
        purchase
      end

      broadcast_purchase_voided(purchase, reason)
      purchase
    end

    private

    def ensure_same_store!(purchase)
      return if purchase.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_received!(purchase)
      return if purchase.received?

      raise ApplicationError.new("Purchase is not received", code: "purchase_not_received")
    end

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

    def broadcast_purchase_voided(purchase, reason)
      Realtime::Broadcaster.notifications(@store, :purchase_voided, {
        purchase_id: purchase.id,
        purchase_number: purchase.purchase_number,
        reason: reason,
        voided_at: Time.current
      })
    end
  end
end
