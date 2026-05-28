module Api
  module V1
    class StockMovementsController < ApplicationController
      def index
        require_permission!("stock_movements.read")

        movements = StockMovement.includes(:product, :warehouse, :user).order(occurred_at: :desc).limit(params.fetch(:limit, 100))
        movements = movements.where(product_id: params[:product_id]) if params[:product_id].present?
        movements = movements.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        movements = movements.where(movement_type: StockMovement.movement_types[params[:movement_type]]) if params[:movement_type].present?
        movements = movements.where("occurred_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        movements = movements.where("occurred_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?

        render json: { stock_movements: movements.map { |movement| serialize_movement(movement) } }
      end

      def create
        require_permission!("stock_movements.write")

        attributes = stock_movement_params
        ensure_manual_reason!(attributes)
        movement = Inventory::MovementService.new(store: current_store, user: current_user).call(
          product: Product.find(attributes.fetch(:product_id)),
          warehouse: Warehouse.find(attributes.fetch(:warehouse_id)),
          movement_type: attributes.fetch(:movement_type),
          qty: attributes.fetch(:qty),
          unit_cost: attributes[:unit_cost],
          notes: attributes[:notes],
          allow_negative: ActiveModel::Type::Boolean.new.cast(attributes[:allow_negative])
        )

        render json: { stock_movement: serialize_movement(movement) }, status: :created
      end

      def transfer
        require_permission!("stock_movements.write")

        outgoing, incoming = Inventory::TransferService.new(store: current_store, user: current_user).call(
          product_id: transfer_params.fetch(:product_id),
          from_warehouse_id: transfer_params.fetch(:from_warehouse_id),
          to_warehouse_id: transfer_params.fetch(:to_warehouse_id),
          qty: transfer_params.fetch(:qty),
          notes: transfer_params.fetch(:notes)
        )

        render json: {
          stock_movements: [ serialize_movement(outgoing), serialize_movement(incoming) ]
        }, status: :created
      end

      private

      def stock_movement_params
        params.require(:stock_movement).permit(
          :product_id,
          :warehouse_id,
          :movement_type,
          :qty,
          :unit_cost,
          :notes,
          :allow_negative
        ).to_h.deep_symbolize_keys
      end

      def transfer_params
        params.require(:transfer).permit(:product_id, :from_warehouse_id, :to_warehouse_id, :qty, :notes)
      end

      def ensure_manual_reason!(attributes)
        return unless attributes[:movement_type].to_s == "adjustment" && attributes[:notes].blank?

        raise ApplicationError.new("Adjustment reason is required", code: "adjustment_reason_required")
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
