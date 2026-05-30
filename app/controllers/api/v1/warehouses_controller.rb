module Api
  module V1
    class WarehousesController < BaseCrudController
      private

      def model_class
        Warehouse
      end

      def permitted_attributes
        [ :branch_id, :code, :name, :active ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.includes(:branch)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        if params.key?(:active)
          scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
        elsif !ActiveModel::Type::Boolean.new.cast(params[:include_inactive])
          scope = scope.where(active: true)
        end
        scope.order(:code).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(warehouse)
        {
          id: warehouse.id,
          store_id: warehouse.store_id,
          branch_id: warehouse.branch_id,
          branch_name: warehouse.branch.name,
          code: warehouse.code,
          name: warehouse.name,
          active: warehouse.active,
          created_at: warehouse.created_at,
          updated_at: warehouse.updated_at
        }
      end
    end
  end
end
