module Api
  module V1
    class StoresController < BaseCrudController
      private

      def model_class
        Store
      end

      def permitted_attributes
        [
          :name,
          :legal_name,
          :commercial_name,
          :nit,
          :nrc,
          :economic_activity_code,
          :economic_activity,
          :email,
          :phone,
          :department,
          :municipality,
          :address,
          :status
        ]
      end

      def resource_scope
        require_superadmin!
        Store.all
      end

      def require_superadmin!
        return if current_user.has_role?(:superadmin)

        raise Pundit::NotAuthorizedError
      end

      def serialize_resource(store)
        store.as_json(only: [
          :id,
          :name,
          :legal_name,
          :commercial_name,
          :nit,
          :nrc,
          :economic_activity_code,
          :economic_activity,
          :email,
          :phone,
          :department,
          :municipality,
          :address,
          :status,
          :created_at,
          :updated_at
        ])
      end
    end
  end
end
