require "test_helper"

module Api
  module V1
    module Auth
      class SessionsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @store = Store.create!(
            name: "Test Store",
            legal_name: "Test Store S.A. de C.V.",
            nit: "0614-020202-102-0",
            status: :active
          )

          ActsAsTenant.with_tenant(@store) do
            @branch = Branch.create!(
              store: @store,
              code: "MAIN",
              name: "Main",
              status: :active
            )
          end

          @user = User.create!(
            store: @store,
            branch: @branch,
            email: "admin@test.local",
            full_name: "Admin Test",
            password: "password123",
            password_confirmation: "password123"
          )

          role = Role.create!(name: "admin")

          ActsAsTenant.with_tenant(@store) do
            UserRole.create!(store: @store, user: @user, role: role)
          end
        end

        teardown do
          ActsAsTenant.current_tenant = nil
        end

        test "login returns jwt and current profile" do
          post api_v1_user_session_path,
            params: { user: { email: @user.email, password: "password123" } },
            as: :json

          assert_response :success
          assert_predicate response.headers["Authorization"], :present?
          assert_equal @user.email, response.parsed_body.dig("user", "email")

          get api_v1_me_path,
            headers: { "Authorization" => response.headers["Authorization"] },
            as: :json

          assert_response :success
          assert_equal @store.id, response.parsed_body.dig("store", "id")
        end
      end
    end
  end
end
