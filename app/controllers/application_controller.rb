class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_current_store
  after_action :clear_current_store

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

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
