module Sales
  class VoidService
    def initialize(store:, user:)
      @store = store
      @user = user
      @inventory = Inventory::MovementService.new(store: store, user: user)
    end

    def call(sale_id:, reason:)
      sale = Sale.transaction do
        sale = Sale.lock.find(sale_id)
        ensure_same_store!(sale)
        ensure_voidable!(sale)

        StockMovement.sale.where(reference: sale).includes(:product, :warehouse).find_each do |movement|
          @inventory.call(
            product: movement.product,
            warehouse: movement.warehouse,
            movement_type: :void,
            qty: -movement.qty,
            unit_cost: movement.unit_cost,
            reference: sale,
            notes: reason,
            allow_negative: true
          )
        end

        sale.payments.update_all(status: Payment.statuses[:voided], updated_at: Time.current)
        sale.invoice&.update!(status: :voided, voided_at: Time.current)
        sale.update!(status: :voided, voided_at: Time.current, void_reason: reason)
        audit!("sale.void", sale, reason: reason, total: sale.total)
        sale
      end

      broadcast_sale_voided(sale)
      sale
    end

    private

    def ensure_same_store!(sale)
      return if sale.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_voidable!(sale)
      return if sale.paid?

      raise ApplicationError.new("Only paid sales can be voided", code: "sale_not_voidable")
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

    def broadcast_sale_voided(sale)
      payload = {
        sale_id: sale.id,
        sale_number: sale.sale_number,
        branch_id: sale.branch_id,
        cashier_id: sale.cashier_id,
        total: sale.total,
        status: sale.status,
        void_reason: sale.void_reason,
        voided_at: sale.voided_at
      }

      Realtime::Broadcaster.sales(@store, :sale_voided, payload)
      Realtime::Broadcaster.sales(@store, :daily_total_updated, daily_total_payload)
      Realtime::Broadcaster.pos(@store, :terminal_sync, payload.merge(resource: "sale"))
    end

    def daily_total_payload
      range = Time.zone.today.beginning_of_day..Time.zone.today.end_of_day

      {
        date: Time.zone.today.iso8601,
        sales_count: Sale.where(status: :paid, sold_at: range).count,
        total: Sale.where(status: :paid, sold_at: range).sum(:total)
      }
    end
  end
end
