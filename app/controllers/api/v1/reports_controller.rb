module Api
  module V1
    class ReportsController < ApplicationController
      def daily_sales
        require_permission!("reports.read")

        date = params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
        range = date.beginning_of_day..date.end_of_day
        sales = paid_sales_in(range)

        render json: sales_totals_payload(sales).merge(
          date: date,
          payment_summary: payment_summary_for(sales)
        )
      end

      def sales
        require_permission!("reports.read")

        sales = paid_sales_in(date_range)

        render json: sales_totals_payload(sales).merge(
          from: date_range.begin,
          to: date_range.end
        )
      end

      def sales_by_cashier
        require_permission!("reports.read")

        rows = paid_sales_in(date_range)
          .joins(:cashier)
          .group("users.id", "users.full_name")
          .pluck("users.id", "users.full_name", Arel.sql("COUNT(DISTINCT sales.id)"), Arel.sql("SUM(sales.total)"))

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          cashiers: rows.map do |id, name, count, total|
            { cashier_id: id, cashier_name: name, sales_count: count, total: total }
          end
        }
      end

      def sales_by_hour
        require_permission!("reports.read")

        rows = paid_sales_in(date_range)
          .group(Arel.sql("DATE_FORMAT(sales.sold_at, '%Y-%m-%d %H:00:00')"))
          .order(Arel.sql("DATE_FORMAT(sales.sold_at, '%Y-%m-%d %H:00:00') ASC"))
          .pluck(
            Arel.sql("DATE_FORMAT(sales.sold_at, '%Y-%m-%d %H:00:00')"),
            Arel.sql("COUNT(DISTINCT sales.id)"),
            Arel.sql("SUM(sales.total)")
          )

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          hours: rows.map do |hour, count, total|
            { hour: hour, sales_count: count, total: total }
          end
        }
      end

      def payment_methods
        require_permission!("reports.read")

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          payment_methods: payment_summary_for(paid_sales_in(date_range))
        }
      end

      def top_products
        require_permission!("reports.read")

        rows = SaleItem.joins(:product)
          .where(sale_id: paid_sales_in(date_range).select(:id))
          .group("products.id", "products.sku", "products.name")
          .order(Arel.sql("SUM(sale_items.quantity) DESC"))
          .limit(params.fetch(:limit, 20))
          .pluck(
            "products.id",
            "products.sku",
            "products.name",
            Arel.sql("SUM(sale_items.quantity)"),
            Arel.sql("SUM(sale_items.total)")
          )

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          products: rows.map do |id, sku, name, quantity, total|
            { product_id: id, sku: sku, product_name: name, quantity: quantity, total: total }
          end
        }
      end

      def gross_margin
        require_permission!("reports.read")

        items = SaleItem.where(sale_id: paid_sales_in(date_range).select(:id))
        revenue = items.sum(:total)
        cost = items.sum("sale_items.unit_cost * sale_items.quantity")

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          revenue: revenue,
          cost: cost,
          gross_margin: revenue - cost
        }
      end

      def low_stock
        require_permission!("reports.read")

        items = InventoryItem.includes(:product, warehouse: :branch)
        items = items.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        items = items.where(warehouses: { branch_id: params[:branch_id] }).references(:warehouses) if params[:branch_id].present?
        items = items.select(&:low_stock?)

        render json: {
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          products: items.map do |item|
            {
              product_id: item.product_id,
              product_name: item.product.name,
              sku: item.product.sku,
              warehouse_id: item.warehouse_id,
              warehouse_name: item.warehouse.name,
              branch_id: item.warehouse.branch_id,
              branch_name: item.warehouse.branch.name,
              quantity: item.quantity,
              min_stock: item.min_stock
            }
          end
        }
      end

      def kardex
        require_permission!("reports.read")

        movements = StockMovement.includes(:product, :user, warehouse: :branch)
          .order(:occurred_at, :id)
          .where(occurred_at: date_range)
        movements = movements.where(product_id: params[:product_id]) if params[:product_id].present?
        movements = movements.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        movements = movements.joins(:warehouse).where(warehouses: { branch_id: params[:branch_id] }) if params[:branch_id].present?

        render json: {
          from: date_range.begin,
          to: date_range.end,
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id],
          product_id: params[:product_id],
          movements: movements.map do |movement|
            {
              id: movement.id,
              product_id: movement.product_id,
              product_name: movement.product.name,
              warehouse_id: movement.warehouse_id,
              warehouse_name: movement.warehouse.name,
              branch_id: movement.warehouse.branch_id,
              branch_name: movement.warehouse.branch.name,
              movement_type: movement.movement_type,
              qty: movement.qty,
              unit_cost: movement.unit_cost,
              reference_type: movement.reference_type,
              reference_id: movement.reference_id,
              occurred_at: movement.occurred_at
            }
          end
        }
      end

      private

      def paid_sales_in(range)
        scope = Sale.where(sold_at: range, status: :paid)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.where(id: sale_ids_for_warehouse) if params[:warehouse_id].present?
        scope
      end

      def sale_ids_for_warehouse
        StockMovement.sale
          .where(warehouse_id: params[:warehouse_id], reference_type: "Sale")
          .select(:reference_id)
      end

      def payment_summary_for(sales)
        payments = Payment.joins(:sale)
          .where(status: Payment.statuses[:received])
          .where(sales: { id: sales.select(:id) })

        counts = payments.group(:method).count

        payments.group(:method).sum(:amount).map do |method, amount|
          { method: method, amount: amount, payments_count: counts.fetch(method, 0) }
        end
      end

      def sales_totals_payload(sales)
        {
          sales_count: sales.count,
          subtotal: sales.sum(:subtotal),
          tax: sales.sum(:tax),
          discount: sales.sum(:discount),
          total: sales.sum(:total),
          branch_id: params[:branch_id],
          warehouse_id: params[:warehouse_id]
        }
      end

      def date_range
        from = params[:from].present? ? Time.zone.parse(params[:from]) : Time.zone.today.beginning_of_day
        to = params[:to].present? ? Time.zone.parse(params[:to]) : Time.zone.today.end_of_day

        from..to
      end
    end
  end
end
