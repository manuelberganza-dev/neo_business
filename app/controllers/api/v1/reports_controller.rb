module Api
  module V1
    class ReportsController < ApplicationController
      def daily_sales
        require_permission!("reports.read")

        date = params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
        sales = paid_sales_in(date.beginning_of_day..date.end_of_day)

        render json: {
          date: date,
          sales_count: sales.count,
          subtotal: sales.sum(:subtotal),
          tax: sales.sum(:tax),
          discount: sales.sum(:discount),
          total: sales.sum(:total)
        }
      end

      def sales
        require_permission!("reports.read")

        sales = paid_sales_in(date_range)

        render json: {
          from: date_range.begin,
          to: date_range.end,
          sales_count: sales.count,
          subtotal: sales.sum(:subtotal),
          tax: sales.sum(:tax),
          discount: sales.sum(:discount),
          total: sales.sum(:total)
        }
      end

      def sales_by_cashier
        require_permission!("reports.read")

        rows = paid_sales_in(date_range)
          .joins(:cashier)
          .group("users.id", "users.full_name")
          .pluck("users.id", "users.full_name", Arel.sql("COUNT(sales.id)"), Arel.sql("SUM(sales.total)"))

        render json: {
          from: date_range.begin,
          to: date_range.end,
          cashiers: rows.map do |id, name, count, total|
            { cashier_id: id, cashier_name: name, sales_count: count, total: total }
          end
        }
      end

      def top_products
        require_permission!("reports.read")

        rows = SaleItem.joins(:sale, :product)
          .where(sales: { status: Sale.statuses[:paid], sold_at: date_range })
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
          products: rows.map do |id, sku, name, quantity, total|
            { product_id: id, sku: sku, product_name: name, quantity: quantity, total: total }
          end
        }
      end

      def gross_margin
        require_permission!("reports.read")

        items = SaleItem.joins(:sale).where(sales: { status: Sale.statuses[:paid], sold_at: date_range })
        revenue = items.sum(:total)
        cost = items.sum("sale_items.unit_cost * sale_items.quantity")

        render json: {
          from: date_range.begin,
          to: date_range.end,
          revenue: revenue,
          cost: cost,
          gross_margin: revenue - cost
        }
      end

      def low_stock
        require_permission!("reports.read")

        items = InventoryItem.includes(:product, :warehouse).select(&:low_stock?)

        render json: {
          products: items.map do |item|
            {
              product_id: item.product_id,
              product_name: item.product.name,
              sku: item.product.sku,
              warehouse_id: item.warehouse_id,
              warehouse_name: item.warehouse.name,
              quantity: item.quantity,
              min_stock: item.min_stock
            }
          end
        }
      end

      def kardex
        require_permission!("reports.read")

        movements = StockMovement.includes(:product, :warehouse, :user).order(:occurred_at, :id)
        movements = movements.where(product_id: params[:product_id]) if params[:product_id].present?
        movements = movements.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        movements = movements.where(occurred_at: date_range)

        render json: {
          from: date_range.begin,
          to: date_range.end,
          product_id: params[:product_id],
          warehouse_id: params[:warehouse_id],
          movements: movements.map do |movement|
            {
              id: movement.id,
              product_id: movement.product_id,
              product_name: movement.product.name,
              warehouse_id: movement.warehouse_id,
              warehouse_name: movement.warehouse.name,
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
        Sale.where(sold_at: range, status: :paid)
      end

      def date_range
        from = params[:from].present? ? Time.zone.parse(params[:from]) : Time.zone.today.beginning_of_day
        to = params[:to].present? ? Time.zone.parse(params[:to]) : Time.zone.today.end_of_day

        from..to
      end
    end
  end
end
