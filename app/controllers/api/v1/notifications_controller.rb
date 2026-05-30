module Api
  module V1
    class NotificationsController < ApplicationController
      def index
        require_permission!("notifications.read")

        notifications = Notification.includes(:user).order(created_at: :desc)
        notifications = apply_filters(notifications)

        render json: { notifications: notifications.limit(params.fetch(:limit, 100)).map { |notification| serialize_notification(notification) } }
      end

      def show
        require_permission!("notifications.read")

        notification = Notification.includes(:user).find(params[:id])
        render json: { notification: serialize_notification(notification) }
      end

      def read
        require_permission!("notifications.write")

        notification = Notification.find(params[:id])
        notification.update!(read_at: Time.current)

        render json: { notification: serialize_notification(notification) }
      end

      def read_all
        require_permission!("notifications.write")

        notifications = apply_filters(Notification.all)
        read_count = notifications.count
        notifications.update_all(read_at: Time.current, updated_at: Time.current)

        render json: { read_count: read_count }
      end

      private

      def apply_filters(notifications)
        notifications = notifications.where(event: params[:event]) if params[:event].present?
        notifications = notifications.where(user_id: [ nil, current_user.id ]) if ActiveModel::Type::Boolean.new.cast(params[:mine])
        notifications = notifications.where(read_at: nil) if ActiveModel::Type::Boolean.new.cast(params[:unread])
        notifications = notifications.where("created_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        notifications = notifications.where("created_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?
        notifications
      end

      def serialize_notification(notification)
        {
          id: notification.id,
          store_id: notification.store_id,
          user_id: notification.user_id,
          user_name: notification.user&.full_name,
          event: notification.event,
          title: notification.title,
          body: notification.body,
          metadata: notification.metadata || {},
          read: notification.read?,
          read_at: notification.read_at,
          created_at: notification.created_at
        }
      end
    end
  end
end
