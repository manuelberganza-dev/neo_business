module Sales
  class CreateService
    def initialize(store:, user:)
      @store = store
      @user = user
      @inventory = Inventory::MovementService.new(store: store, user: user)
    end

    def call(attributes)
      idempotency_key = attributes[:idempotency_key].presence
      existing_sale = Sale.find_by(idempotency_key: idempotency_key) if idempotency_key
      return existing_sale if existing_sale

      sale = Sale.transaction do
        cash_session = CashSession.lock.find(attributes.fetch(:cash_session_id))
        ensure_open_cash_session!(cash_session)

        branch = Branch.find(attributes[:branch_id].presence || cash_session.cash_register.branch_id)
        ensure_same_store!(branch)

        warehouse = Warehouse.find(attributes[:warehouse_id].presence || branch.warehouses.where(active: true).first&.id)
        ensure_same_store!(warehouse)
        ensure_active_warehouse!(warehouse)

        sale = Sale.create!(
          store: @store,
          branch: branch,
          cashier: @user,
          customer_id: attributes[:customer_id],
          cash_session: cash_session,
          sale_number: next_sale_number,
          idempotency_key: idempotency_key,
          status: :draft,
          sold_at: Time.current
        )

        totals = create_items!(sale, warehouse, Array(attributes.fetch(:items)))
        total_discount = BigDecimal(attributes[:discount].presence || "0")
        total = totals[:subtotal] + totals[:tax] - total_discount

        sale.update!(
          subtotal: totals[:subtotal],
          tax: totals[:tax],
          discount: total_discount,
          total: total
        )

        create_payments!(sale, Array(attributes.fetch(:payments)), total)
        create_invoice!(sale, attributes[:invoice]) if attributes[:invoice].present?

        sale.update!(status: :paid)
        audit!("sale.create", sale, total: sale.total, item_count: sale.sale_items.count)
        sale
      end

      broadcast_sale_created(sale)
      sale
    end

    private

    def create_items!(sale, warehouse, items)
      raise ApplicationError.new("Sale must include at least one item", code: "sale_items_required") if items.empty?

      items.each_with_object({ subtotal: 0.to_d, tax: 0.to_d }) do |item_attributes, totals|
        product = Product.lock.find(item_attributes.fetch(:product_id))
        ensure_same_store!(product)

        quantity = BigDecimal(item_attributes.fetch(:quantity).to_s)
        raise ApplicationError.new("Item quantity must be greater than zero", code: "invalid_quantity") unless quantity.positive?

        unit_price = BigDecimal((item_attributes[:unit_price].presence || product.price).to_s)
        discount = BigDecimal((item_attributes[:discount].presence || "0").to_s)
        line_subtotal = (unit_price * quantity) - discount
        line_tax = line_subtotal * product.tax_rate
        line_total = line_subtotal + line_tax

        sale_item = SaleItem.create!(
          store: @store,
          sale: sale,
          product: product,
          quantity: quantity,
          unit_price: unit_price,
          unit_cost: product.cost,
          discount: discount,
          tax_rate: product.tax_rate,
          tax: line_tax,
          total: line_total
        )

        if product.track_inventory?
          @inventory.call(
            product: product,
            warehouse: warehouse,
            movement_type: :sale,
            qty: -quantity,
            unit_cost: product.cost,
            reference: sale,
            notes: "Sale item ##{sale_item.id}"
          )
        end

        totals[:subtotal] += line_subtotal
        totals[:tax] += line_tax
      end
    end

    def create_payments!(sale, payments, total)
      raise ApplicationError.new("Sale must include at least one payment", code: "payments_required") if payments.empty?

      paid_total = payments.sum { |payment| BigDecimal(payment.fetch(:amount).to_s) }
      if paid_total < total
        raise ApplicationError.new("Payments do not cover sale total", code: "insufficient_payment")
      end

      payments.each do |payment_attributes|
        payment_method = find_payment_method(payment_attributes)

        Payment.create!(
          store: @store,
          sale: sale,
          payment_method: payment_method,
          method: payment_attributes.fetch(:method).to_s,
          amount: payment_attributes.fetch(:amount),
          reference: payment_attributes[:reference],
          status: :received,
          paid_at: Time.current
        )
      end
    end

    def create_invoice!(sale, invoice_attributes)
      customer = sale.customer

      Invoice.create!(
        store: @store,
        sale: sale,
        doc_type: invoice_attributes[:doc_type].presence || "ticket",
        control_number: invoice_attributes[:control_number],
        generation_code: invoice_attributes[:generation_code],
        customer_name: invoice_attributes[:customer_name].presence || customer&.name,
        customer_document_type: invoice_attributes[:customer_document_type].presence || customer&.document_type,
        customer_document_number: invoice_attributes[:customer_document_number].presence || customer&.document_number,
        customer_nit: invoice_attributes[:customer_nit].presence || customer&.nit,
        customer_nrc: invoice_attributes[:customer_nrc].presence || customer&.nrc,
        customer_email: invoice_attributes[:customer_email].presence || customer&.email,
        subtotal: sale.subtotal,
        tax: sale.tax,
        discount: sale.discount,
        total: sale.total,
        status: :draft
      )
    end

    def find_payment_method(payment_attributes)
      return PaymentMethod.find(payment_attributes[:payment_method_id]) if payment_attributes[:payment_method_id].present?

      PaymentMethod.find_by(code: payment_attributes[:method].to_s.upcase)
    end

    def ensure_open_cash_session!(cash_session)
      ensure_same_store!(cash_session)
      return if cash_session.open?

      raise ApplicationError.new("Cash session is not open", code: "cash_session_not_open")
    end

    def ensure_same_store!(record)
      return if record&.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_active_warehouse!(warehouse)
      return if warehouse.active?

      raise ApplicationError.new("Warehouse is inactive", code: "warehouse_inactive")
    end

    def next_sale_number
      "V#{Time.current.strftime("%Y%m%d%H%M%S%6N")}"
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

    def broadcast_sale_created(sale)
      payload = {
        sale_id: sale.id,
        sale_number: sale.sale_number,
        branch_id: sale.branch_id,
        cashier_id: sale.cashier_id,
        total: sale.total,
        status: sale.status,
        sold_at: sale.sold_at
      }

      Realtime::Broadcaster.sales(@store, :sale_created, payload)
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
