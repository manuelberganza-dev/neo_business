module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        skip_before_action :authenticate_user!, only: :create
        skip_before_action :set_current_store, only: :create
        skip_after_action :clear_current_store, only: :create

        def create
          user = User.find_for_database_authentication(email: login_params[:email].to_s.downcase)

          if user&.valid_password?(login_params[:password]) && user.active_for_authentication?
            sign_in(:user, user, store: false)
            response.set_header("Authorization", "Bearer #{jwt_for(user)}")
            payload = ActsAsTenant.with_tenant(user.store) do
              {
                user: user_payload(user),
                store: store_payload(user.store)
              }
            end

            render json: payload, status: :ok
          else
            render json: { error: "invalid_credentials" }, status: :unauthorized
          end
        end

        def destroy
          head :no_content
        end

        private

        def login_params
          params.require(:user).permit(:email, :password)
        end

        def jwt_for(user)
          Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        end

        def user_payload(user)
          {
            id: user.id,
            email: user.email,
            full_name: user.full_name,
            active: user.active,
            store_id: user.store_id,
            branch_id: user.branch_id,
            roles: user.roles.pluck(:name)
          }
        end

        def store_payload(store)
          {
            id: store.id,
            name: store.name,
            legal_name: store.legal_name,
            nit: store.nit,
            nrc: store.nrc
          }
        end
      end
    end
  end
end
