class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for_store(:notifications)
    stream_from Realtime::Broadcaster.user_stream_name(current_user, :notifications)
  end
end
