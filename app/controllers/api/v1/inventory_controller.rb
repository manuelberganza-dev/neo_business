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

      def update
        require_permission!("inventory_items.write")

        item = InventoryItem.find(params[:id])
        item.update!(inventory_params)

        render json: { inventory_item: serialize_inventory_item(item) }
      end

      def product_kardex
        require_permission!("stock_movements.read")

        movements = StockMovement.includes(:warehouse, :user)
          .where(product_id: params.fetch(:product_id))
          .order(:occurred_at, :id)

        render json: {
          product_id: params.fetch(:product_id).to_i,
          kardex: movements.map { |movement| serialize_movement(movement) }
        }
      end

      def warehouse_history
        require_permission!("stock_movements.read")

        movements = StockMovement.includes(:product, :user)
          .where(warehouse_id: params.fetch(:warehouse_id))
          .order(occurred_at: :desc, id: :desc)
          .limit(params.fetch(:limit, 100))

        render json: {
          warehouse_id: params.fetch(:warehouse_id).to_i,
          history: movements.map { |movement| serialize_movement(movement) }
        }
      end

      private

      def inventory_params
        params.require(:inventory_item).permit(:min_stock)
      end

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

      def serialize_movement(movement)
        {
          id: movement.id,
          product_id: movement.product_id,
          product_name: movement.product.name,
          warehouse_id: movement.warehouse_id,
          warehouse_name: movement.warehouse.name,
          user_id: movement.user_id,
          movement_type: movement.movement_type,
          qty: movement.qty,
          unit_cost: movement.unit_cost,
          reference_type: movement.reference_type,
          reference_id: movement.reference_id,
          notes: movement.notes,
          occurred_at: movement.occurred_at
        }
      end
    end
  end
end
