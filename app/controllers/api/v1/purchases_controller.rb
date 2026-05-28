module Api
  module V1
    class PurchasesController < ApplicationController
      def create
        require_permission!("purchases.write")

        purchase = Purchases::CreateService.new(store: current_store, user: current_user).call(purchase_params)
        render json: { purchase: serialize_purchase(purchase) }, status: :created
      end

      private

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

      def serialize_purchase(purchase)
        {
          id: purchase.id,
          purchase_number: purchase.purchase_number,
          supplier_id: purchase.supplier_id,
          warehouse_id: purchase.warehouse_id,
          invoice_number: purchase.invoice_number,
          subtotal: purchase.subtotal,
          tax: purchase.tax,
          discount: purchase.discount,
          total: purchase.total,
          status: purchase.status,
          purchased_at: purchase.purchased_at,
          items: purchase.purchase_items.map do |item|
            {
              id: item.id,
              product_id: item.product_id,
              quantity: item.quantity,
              cost: item.cost,
              tax_rate: item.tax_rate,
              tax: item.tax,
              total: item.total
            }
          end
        }
      end
    end
  end
end
