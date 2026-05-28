module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    def require_permission!(permission_key)
      return if current_user.has_role?(:admin) || current_user.permission_keys.include?(permission_key)

      reject
    end

    def stream_for_store(topic)
      stream_from Realtime::Broadcaster.stream_name(current_store, topic)
    end
  end
end
