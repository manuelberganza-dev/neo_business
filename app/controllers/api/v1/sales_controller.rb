module Api
  module V1
    class SalesController < ApplicationController
      def index
        require_permission!("sales.read")

        sales = Sale.includes(:customer, :cashier)
          .order(sold_at: :desc)

        sales = sales.where(status: Sale.statuses[params[:status]]) if params[:status].present?
        sales = sales.where("sold_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        sales = sales.where("sold_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?
        sales = sales.where(sale_number: params[:sale_number]) if params[:sale_number].present?
        sales = sales.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        sales = sales.where(cash_session_id: params[:cash_session_id]) if params[:cash_session_id].present?
        sales = sales.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        sales = sales.where(cashier_id: params[:cashier_id]) if params[:cashier_id].present?

        render json: { sales: sales.limit(params.fetch(:limit, 50)).map { |sale| serialize_sale_summary(sale) } }
      end

      def show
        require_permission!("sales.read")

        sale = Sale.includes(:sale_items, :payments, :invoice).find(params[:id])
        render json: { sale: serialize_sale(sale) }
      end

      def create
        require_permission!("sales.write")

        sale = Sales::CreateService.new(store: current_store, user: current_user).call(sale_params)
        render json: { sale: serialize_sale(sale) }, status: :created
      end

      def void
        require_permission!("sales.write")

        sale = Sales::VoidService.new(store: current_store, user: current_user).call(
          sale_id: params.fetch(:id),
          reason: void_params.fetch(:reason)
        )

        render json: { sale: serialize_sale(sale) }, status: :ok
      end

      private

      def sale_params
        params.require(:sale).permit(
          :branch_id,
          :customer_id,
          :cash_session_id,
          :warehouse_id,
          :discount,
          :idempotency_key,
          items: [ :product_id, :quantity, :unit_price, :discount ],
          payments: [ :payment_method_id, :method, :amount, :reference ],
          invoice: [
            :doc_type,
            :control_number,
            :generation_code,
            :customer_name,
            :customer_document_type,
            :customer_document_number,
            :customer_nit,
            :customer_nrc,
            :customer_email
          ]
        ).to_h.deep_symbolize_keys
      end

      def void_params
        params.require(:sale).permit(:reason)
      end

      def serialize_sale_summary(sale)
        {
          id: sale.id,
          sale_number: sale.sale_number,
          customer_id: sale.customer_id,
          customer_name: sale.customer&.name,
          branch_id: sale.branch_id,
          cash_session_id: sale.cash_session_id,
          cashier_id: sale.cashier_id,
          cashier_name: sale.cashier.full_name,
          total: sale.total,
          status: sale.status,
          sold_at: sale.sold_at
        }
      end

      def serialize_sale(sale)
        serialize_sale_summary(sale).merge(
          branch_id: sale.branch_id,
          cash_session_id: sale.cash_session_id,
          subtotal: sale.subtotal,
          tax: sale.tax,
          discount: sale.discount,
          void_reason: sale.void_reason,
          voided_at: sale.voided_at,
          items: sale.sale_items.map { |item| serialize_sale_item(item) },
          payments: sale.payments.map { |payment| serialize_payment(payment) },
          invoice_id: sale.invoice&.id
        )
      end

      def serialize_sale_item(item)
        {
          id: item.id,
          product_id: item.product_id,
          quantity: item.quantity,
          unit_price: item.unit_price,
          unit_cost: item.unit_cost,
          discount: item.discount,
          tax_rate: item.tax_rate,
          tax: item.tax,
          total: item.total
        }
      end

      def serialize_payment(payment)
        {
          id: payment.id,
          method: payment.method,
          amount: payment.amount,
          reference: payment.reference,
          status: payment.status,
          paid_at: payment.paid_at
        }
      end
    end
  end
end
