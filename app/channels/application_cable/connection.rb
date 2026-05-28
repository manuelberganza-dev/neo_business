module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_store

    def connect
      self.current_user = find_verified_user
      self.current_store = current_user.store
      ActsAsTenant.current_tenant = current_store
    end

    def disconnect
      ActsAsTenant.current_tenant = nil
    end

    private

    def find_verified_user
      token = request.params[:token].presence || request.headers["Authorization"].to_s.split.last
      reject_unauthorized_connection if token.blank?

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      user = User.find_by(id: payload["sub"])

      return user if user&.active_for_authentication? && user.jti == payload["jti"]

      reject_unauthorized_connection
    rescue JWT::DecodeError, Warden::JWTAuth::Errors::RevokedToken
      reject_unauthorized_connection
    end
  end
end
