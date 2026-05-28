module Api
  module V1
    class InventoryController < ApplicationController
      def index
        require_permission!("inventory_items.read")

        items = InventoryItem.includes(:product, :warehouse).order(:product_id, :warehouse_id)
        items = items.where(product_id: params[:product_id]) if params[:product_id].present?
        items = items.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        items = items.select(&:low_stock?) if ActiveModel::Type::Boolean.new.cast(params[:low_stock])

        render json: { inventory: items.map { |item| serialize_inventory_item(item) } }
      end

      private

      def serialize_inventory_item(item)
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product.name,
          sku: item.product.sku,
          barcode: item.product.barcode,
          warehouse_id: item.warehouse_id,
          warehouse_name: item.warehouse.name,
          quantity: item.quantity,
          min_stock: item.min_stock,
          low_stock: item.low_stock?
        }
      end
    end
  end
end
