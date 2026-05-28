module Api
  module V1
    class CustomersController < BaseCrudController
      private

      def model_class
        Customer
      end

      def permitted_attributes
        [
          :name,
          :document_type,
          :document_number,
          :nit,
          :nrc,
          :email,
          :phone,
          :address,
          :active
        ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where("nit LIKE ?", "%#{params[:nit]}%") if params[:nit].present?
        scope = scope.where("nrc LIKE ?", "%#{params[:nrc]}%") if params[:nrc].present?
        scope = scope.where("document_number LIKE ?", "%#{params[:document_number]}%") if params[:document_number].present?
        scope = scope.where("phone LIKE ?", "%#{params[:phone]}%") if params[:phone].present?
        scope.order(:name).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(customer)
        customer.as_json(only: [
          :id,
          :store_id,
          :name,
          :document_type,
          :document_number,
          :nit,
          :nrc,
          :email,
          :phone,
          :address,
          :active,
          :created_at,
          :updated_at
        ])
      end
    end
  end
end
