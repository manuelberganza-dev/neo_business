module Api
  module V1
    class RolesController < BaseCrudController
      private

      def model_class
        Role
      end

      def permitted_attributes
        [ :name, :description, :system_role, permission_ids: [] ]
      end

      def resource_scope
        Role.includes(:permissions)
      end

      def resource_params
        params.require(:role).permit(:name, :description, :system_role)
      end

      def after_save(record)
        return unless params.dig(:role, :permission_ids)

        record.permissions = Permission.where(id: params[:role][:permission_ids])
      end

      def serialize_resource(role)
        {
          id: role.id,
          name: role.name,
          description: role.description,
          system_role: role.system_role,
          permissions: role.permissions.order(:key).map do |permission|
            permission.as_json(only: [ :id, :key, :description ])
          end,
          created_at: role.created_at,
          updated_at: role.updated_at
        }
      end
    end
  end
end
