module Api
  module V1
    class CashRegistersController < BaseCrudController
      private

      def model_class
        CashRegister
      end

      def permitted_attributes
        [ :branch_id, :code, :name, :status ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.includes(:branch)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.where(status: CashRegister.statuses[params[:status]]) if params[:status].present?
        scope.order(:code).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(cash_register)
        open_session = cash_register.cash_sessions.open.order(opened_at: :desc).first

        {
          id: cash_register.id,
          store_id: cash_register.store_id,
          branch_id: cash_register.branch_id,
          branch_name: cash_register.branch.name,
          code: cash_register.code,
          name: cash_register.name,
          status: cash_register.status,
          current_cash_session_id: open_session&.id,
          created_at: cash_register.created_at,
          updated_at: cash_register.updated_at
        }
      end
    end
  end
end
