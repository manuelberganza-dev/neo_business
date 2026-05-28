class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_current_store
  after_action :clear_current_store

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ApplicationError, with: :application_error

  attr_reader :current_store

  private

  def authenticate_user!
    render json: { error: "unauthorized" }, status: :unauthorized unless current_user
  end

  def current_user
    @current_user ||= user_from_authorization_header
  end

  def set_current_store
    @current_store = current_user.store
    ActsAsTenant.current_tenant = current_store
  end

  def clear_current_store
    ActsAsTenant.current_tenant = nil
  end

  def user_not_authorized
    render json: { error: "not_authorized" }, status: :forbidden
  end

  def record_not_found
    render json: { error: "not_found" }, status: :not_found
  end

  def record_invalid(error)
    render json: {
      error: "validation_failed",
      details: error.record.errors.to_hash
    }, status: :unprocessable_entity
  end

  def application_error(error)
    render json: {
      error: error.code,
      message: error.message
    }, status: error.status
  end

  def require_permission!(permission_key)
    return if current_user.has_role?(:admin) || current_user.permission_keys.include?(permission_key)

    raise Pundit::NotAuthorizedError
  end

  def user_from_authorization_header
    token = request.headers["Authorization"].to_s.split.last
    return if token.blank?

    payload = Warden::JWTAuth::TokenDecoder.new.call(token)
    user = User.find_by(id: payload["sub"])

    user if user&.active_for_authentication? && user.jti == payload["jti"]
  rescue JWT::DecodeError, Warden::JWTAuth::Errors::RevokedToken
    nil
  end
end
