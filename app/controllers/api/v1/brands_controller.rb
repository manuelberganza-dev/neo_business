module Api
  module V1
    class BrandsController < BaseCrudController
      private

      def model_class
        Brand
      end

      def permitted_attributes
        [ :name, :active ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope.order(:name).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(brand)
        brand.as_json(only: [ :id, :store_id, :name, :active, :created_at, :updated_at ])
      end
    end
  end
end
