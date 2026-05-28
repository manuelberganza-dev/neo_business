module Api
  module V1
    class ReportsController < ApplicationController
      def daily_sales
        require_permission!("reports.read")

        date = params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
        range = date.beginning_of_day..date.end_of_day
        sales = Sale.where(sold_at: range, status: :paid)

        render json: {
          date: date,
          sales_count: sales.count,
          subtotal: sales.sum(:subtotal),
          tax: sales.sum(:tax),
          discount: sales.sum(:discount),
          total: sales.sum(:total)
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
    end
  end
end
