module Api
  module V1
    class MobileController < ApplicationController
      include Rails.application.routes.url_helpers

      def scan_product
        require_permission!("products.read")

        product = Product.includes(:unit, :category, :brand).find_by!(barcode: scan_params.fetch(:barcode), active: true)
        warehouses = available_warehouses

        render json: {
          product: {
            id: product.id,
            sku: product.sku,
            barcode: product.barcode,
            name: product.name,
            description: product.description,
            unit_id: product.unit_id,
            unit_code: product.unit.code,
            category_id: product.category_id,
            category_name: product.category&.name,
            brand_id: product.brand_id,
            brand_name: product.brand&.name,
            cost: product.cost,
            price: product.price,
            tax_rate: product.tax_rate,
            track_inventory: product.track_inventory,
            active: product.active,
            image_attached: product.image.attached?,
            image_url: product.image.attached? ? rails_blob_path(product.image, only_path: true) : nil
          },
          stock: stock_payload(product, warehouses)
        }
      end

      private

      def scan_params
        params.require(:scan).permit(:barcode, :warehouse_id, :branch_id)
      end

      def available_warehouses
        scope = Warehouse.includes(:branch).where(active: true)
        scope = scope.where(id: scan_params[:warehouse_id]) if scan_params[:warehouse_id].present?
        scope = scope.where(branch_id: scan_params[:branch_id]) if scan_params[:branch_id].present?
        scope = scope.where(branch_id: current_user.branch_id) if scan_params[:branch_id].blank? && scan_params[:warehouse_id].blank? && current_user.branch_id.present?
        scope.order(:code)
      end

      def stock_payload(product, warehouses)
        items = InventoryItem.where(product: product, warehouse: warehouses).index_by(&:warehouse_id)
        rows = warehouses.map do |warehouse|
          item = items[warehouse.id]

          {
            warehouse_id: warehouse.id,
            warehouse_code: warehouse.code,
            warehouse_name: warehouse.name,
            branch_id: warehouse.branch_id,
            branch_name: warehouse.branch.name,
            quantity: item&.quantity || 0.to_d,
            min_stock: item&.min_stock || 0.to_d,
            low_stock: item ? item.low_stock? : true
          }
        end

        {
          total_quantity: rows.sum { |row| row[:quantity] },
          warehouses: rows,
          warehouse: rows.first
        }
      end
    end
  end
end
