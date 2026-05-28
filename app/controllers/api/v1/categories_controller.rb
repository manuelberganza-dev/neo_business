module Api
  module V1
    class CategoriesController < BaseCrudController
      private

      def model_class
        Category
      end

      def permitted_attributes
        [ :parent_id, :name, :active ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope = scope.where(parent_id: params[:parent_id]) if params[:parent_id].present?
        scope.order(:name).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(category)
        category.as_json(only: [ :id, :store_id, :parent_id, :name, :active, :created_at, :updated_at ])
      end
    end
  end
end
