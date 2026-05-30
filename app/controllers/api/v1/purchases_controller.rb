module Api
  module V1
    class PurchasesController < ApplicationController
      def index
        require_permission!("purchases.read")

        purchases = Purchase.includes(:supplier, :warehouse)
          .order(purchased_at: :desc)

        purchases = apply_filters(purchases)
        render json: { purchases: purchases.limit(params.fetch(:limit, 50)).map { |purchase| serialize_purchase_summary(purchase) } }
      end

      def show
        require_permission!("purchases.read")

        purchase = Purchase.includes(:supplier, :warehouse, purchase_items: :product).find(params[:id])
        render json: { purchase: serialize_purchase(purchase) }
      end

      def create
        require_permission!("purchases.write")

        purchase = Purchases::CreateService.new(store: current_store, user: current_user).call(purchase_params)
        render json: { purchase: serialize_purchase(purchase) }, status: :created
      end

      def void
        require_permission!("purchases.write")

        purchase = Purchases::VoidService.new(store: current_store, user: current_user).call(
          purchase_id: params.fetch(:id),
          reason: void_params.fetch(:reason)
        )

        render json: { purchase: serialize_purchase(purchase) }, status: :ok
      end

      private

      def apply_filters(purchases)
        purchases = purchases.where(status: Purchase.statuses[params[:status]]) if params[:status].present?
        purchases = purchases.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
        purchases = purchases.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        purchases = purchases.where("purchased_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        purchases = purchases.where("purchased_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?
        purchases = purchases.where(invoice_number: params[:invoice_number]) if params[:invoice_number].present?
        purchases = purchases.where(purchase_number: params[:purchase_number]) if params[:purchase_number].present?
        purchases
      end

      def purchase_params
        params.require(:purchase).permit(
          :supplier_id,
          :warehouse_id,
          :document_type,
          :invoice_number,
          :discount,
          items: [ :product_id, :quantity, :cost, :tax_rate, :update_product_cost ]
        ).to_h.deep_symbolize_keys
      end

      def void_params
        params.require(:purchase).permit(:reason)
      end

      def serialize_purchase_summary(purchase)
        {
          id: purchase.id,
          purchase_number: purchase.purchase_number,
          supplier_id: purchase.supplier_id,
          supplier_name: purchase.supplier.name,
          warehouse_id: purchase.warehouse_id,
          warehouse_name: purchase.warehouse.name,
          invoice_number: purchase.invoice_number,
          subtotal: purchase.subtotal,
          tax: purchase.tax,
          discount: purchase.discount,
          total: purchase.total,
          status: purchase.status,
          purchased_at: purchase.purchased_at
        }
      end

      def serialize_purchase(purchase)
        serialize_purchase_summary(purchase).merge(
          items: purchase.purchase_items.map do |item|
            {
              id: item.id,
              product_id: item.product_id,
              product_name: item.product.name,
              quantity: item.quantity,
              cost: item.cost,
              tax_rate: item.tax_rate,
              tax: item.tax,
              total: item.total
            }
          end
        )
      end
    end
  end
end
