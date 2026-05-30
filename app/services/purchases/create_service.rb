module Purchases
  class CreateService
    def initialize(store:, user:)
      @store = store
      @user = user
      @inventory = Inventory::MovementService.new(store: store, user: user)
    end

    def call(attributes)
      purchase = Purchase.transaction do
        supplier = Supplier.find(attributes.fetch(:supplier_id))
        warehouse = Warehouse.find(attributes.fetch(:warehouse_id))
        ensure_same_store!(supplier)
        ensure_same_store!(warehouse)
        ensure_active_warehouse!(warehouse)

        purchase = Purchase.create!(
          store: @store,
          supplier: supplier,
          warehouse: warehouse,
          purchase_number: next_purchase_number,
          document_type: attributes[:document_type],
          invoice_number: attributes[:invoice_number],
          status: :draft,
          purchased_at: Time.current
        )

        totals = create_items!(purchase, warehouse, Array(attributes.fetch(:items)))
        purchase.update!(
          subtotal: totals[:subtotal],
          tax: totals[:tax],
          discount: BigDecimal(attributes[:discount].presence || "0"),
          total: totals[:subtotal] + totals[:tax] - BigDecimal(attributes[:discount].presence || "0"),
          status: :received
        )

        audit!("purchase.create", purchase, total: purchase.total, item_count: purchase.purchase_items.count)
        purchase
      end

      broadcast_purchase_received(purchase)
      purchase
    end

    private

    def create_items!(purchase, warehouse, items)
      raise ApplicationError.new("Purchase must include at least one item", code: "purchase_items_required") if items.empty?

      items.each_with_object({ subtotal: 0.to_d, tax: 0.to_d }) do |item_attributes, totals|
        product = Product.lock.find(item_attributes.fetch(:product_id))
        ensure_same_store!(product)

        quantity = BigDecimal(item_attributes.fetch(:quantity).to_s)
        cost = BigDecimal(item_attributes.fetch(:cost).to_s)
        tax_rate = BigDecimal((item_attributes[:tax_rate].presence || product.tax_rate).to_s)
        line_subtotal = quantity * cost
        line_tax = line_subtotal * tax_rate
        line_total = line_subtotal + line_tax

        purchase_item = PurchaseItem.create!(
          store: @store,
          purchase: purchase,
          product: product,
          quantity: quantity,
          cost: cost,
          tax_rate: tax_rate,
          tax: line_tax,
          total: line_total
        )

        @inventory.call(
          product: product,
          warehouse: warehouse,
          movement_type: :purchase,
          qty: quantity,
          unit_cost: cost,
          reference: purchase,
          notes: "Purchase item ##{purchase_item.id}",
          allow_negative: true
        )

        product.update!(cost: cost) if item_attributes[:update_product_cost]
        totals[:subtotal] += line_subtotal
        totals[:tax] += line_tax
      end
    end

    def ensure_same_store!(record)
      return if record.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_active_warehouse!(warehouse)
      return if warehouse.active?

      raise ApplicationError.new("Warehouse is inactive", code: "warehouse_inactive")
    end

    def next_purchase_number
      "C#{Time.current.strftime("%Y%m%d%H%M%S%6N")}"
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

    def broadcast_purchase_received(purchase)
      Realtime::Broadcaster.notifications(@store, :purchase_received, {
        purchase_id: purchase.id,
        purchase_number: purchase.purchase_number,
        supplier_id: purchase.supplier_id,
        warehouse_id: purchase.warehouse_id,
        total: purchase.total,
        purchased_at: purchase.purchased_at
      })
    end
  end
end
