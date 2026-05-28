module Api
  module V1
    class PermissionsController < ApplicationController
      def index
        require_permission!("roles.read")

        permissions = Permission.order(:key)
        render json: {
          permissions: permissions.map { |permission| serialize_permission(permission) }
        }
      end

      private

      def serialize_permission(permission)
        permission.as_json(only: [ :id, :key, :description ])
      end
    end
  end
end
