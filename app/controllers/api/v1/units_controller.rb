module Api
  module V1
    class UnitsController < BaseCrudController
      private

      def model_class
        Unit
      end

      def permitted_attributes
        [ :code, :name, :active ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope.order(:code).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(unit)
        unit.as_json(only: [ :id, :store_id, :code, :name, :active, :created_at, :updated_at ])
      end
    end
  end
end
