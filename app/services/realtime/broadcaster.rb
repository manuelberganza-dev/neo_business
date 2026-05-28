module Realtime
  class Broadcaster
    class << self
      def stream_name(store, topic)
        "store:#{store.id}:#{topic}"
      end

      def user_stream_name(user, topic)
        "store:#{user.store_id}:user:#{user.id}:#{topic}"
      end

      def inventory(store, event, payload = {})
        broadcast(store, :inventory, event, payload)
      end

      def sales(store, event, payload = {})
        broadcast(store, :sales, event, payload)
      end

      def notifications(store, event, payload = {})
        broadcast(store, :notifications, event, payload)
      end

      def user_notification(user, event, payload = {})
        ActionCable.server.broadcast(user_stream_name(user, :notifications), envelope(event, payload))
      end

      def pos(store, event, payload = {})
        broadcast(store, :pos, event, payload)
      end

      private

      def broadcast(store, topic, event, payload)
        ActionCable.server.broadcast(stream_name(store, topic), envelope(event, payload))
      end

      def envelope(event, payload)
        {
          event: event.to_s,
          payload: payload,
          sent_at: Time.current.iso8601
        }
      end
    end
  end
end
