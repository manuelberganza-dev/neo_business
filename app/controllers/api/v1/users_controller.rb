module Api
  module V1
    class UsersController < BaseCrudController
      private

      def model_class
        User
      end

      def permitted_attributes
        [ :branch_id, :email, :full_name, :password, :password_confirmation, :active, role_ids: [] ]
      end

      def resource_scope
        User.includes(:branch, :roles)
      end

      def resource_params
        attributes = params.require(:user).permit(:branch_id, :email, :full_name, :password, :password_confirmation, :active)
        attributes = attributes.except(:password, :password_confirmation) if attributes[:password].blank?
        attributes.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.where("email LIKE ?", "%#{params[:email]}%") if params[:email].present?
        scope = scope.where("full_name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope.order(:full_name).limit(params.fetch(:limit, 100))
      end

      def after_save(record)
        return unless params.dig(:user, :role_ids)

        UserRole.where(store: current_store, user: record).delete_all
        Role.where(id: params[:user][:role_ids]).find_each do |role|
          UserRole.create!(store: current_store, user: record, role: role)
        end
      end

      def serialize_resource(user)
        {
          id: user.id,
          store_id: user.store_id,
          branch_id: user.branch_id,
          branch_name: user.branch&.name,
          email: user.email,
          full_name: user.full_name,
          active: user.active,
          roles: user.roles.map { |role| role.as_json(only: [ :id, :name, :description ]) },
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
    end
  end
end
