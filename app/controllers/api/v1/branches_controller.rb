module Api
  module V1
    class BranchesController < BaseCrudController
      private

      def model_class
        Branch
      end

      def permitted_attributes
        [ :code, :name, :address, :phone, :establishment_code, :point_of_sale_code, :is_main, :status ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def serialize_resource(branch)
        branch.as_json(only: [
          :id,
          :store_id,
          :code,
          :name,
          :address,
          :phone,
          :establishment_code,
          :point_of_sale_code,
          :is_main,
          :status,
          :created_at,
          :updated_at
        ])
      end
    end
  end
end
