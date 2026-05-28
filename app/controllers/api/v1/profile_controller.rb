module Api
  module V1
    class ProfileController < ApplicationController
      def show
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email,
            full_name: current_user.full_name,
            store_id: current_user.store_id,
            branch_id: current_user.branch_id,
            roles: current_user.roles.pluck(:name),
            permissions: current_user.permission_keys
          },
          store: {
            id: current_store.id,
            name: current_store.name,
            legal_name: current_store.legal_name,
            nit: current_store.nit,
            nrc: current_store.nrc
          }
        }
      end
    end
  end
end
