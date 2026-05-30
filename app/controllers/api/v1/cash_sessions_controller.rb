module Api
  module V1
    class CashSessionsController < ApplicationController
      def current
        require_permission!("cash_sessions.read")

        session = CashSession.open
          .includes(cash_register: :branch)
          .order(opened_at: :desc)

        session = session.where(cash_register_id: params[:cash_register_id]) if params[:cash_register_id].present?
        session = session.where(user_id: current_user.id) if ActiveModel::Type::Boolean.new.cast(params[:mine])
        session = session.first

        render json: { cash_session: session ? serialize_cash_session(session) : nil }
      end

      def open
        require_permission!("cash_sessions.write")

        session = CashSessions::OpenService.new(store: current_store, user: current_user).call(
          cash_register_id: cash_session_params.fetch(:cash_register_id),
          opening_amount: cash_session_params.fetch(:opening_amount)
        )

        render json: serialize_cash_session(session), status: :created
      end

      def close
        require_permission!("cash_sessions.write")

        session = CashSessions::CloseService.new(store: current_store, user: current_user).call(
          cash_session_id: params.fetch(:id),
          closing_amount: cash_session_params.fetch(:closing_amount)
        )

        render json: serialize_cash_session(session), status: :ok
      end

      private

      def cash_session_params
        params.require(:cash_session).permit(:cash_register_id, :opening_amount, :closing_amount)
      end

      def serialize_cash_session(session)
        {
          id: session.id,
          cash_register_id: session.cash_register_id,
          cash_register_name: session.cash_register.name,
          branch_id: session.cash_register.branch_id,
          branch_name: session.cash_register.branch.name,
          user_id: session.user_id,
          opening_amount: session.opening_amount,
          closing_amount: session.closing_amount,
          expected_amount: session.expected_amount,
          difference_amount: session.difference_amount,
          payment_summary: payment_summary(session),
          status: session.status,
          opened_at: session.opened_at,
          closed_at: session.closed_at
        }
      end

      def payment_summary(session)
        payments = Payment.joins(:sale)
          .where(sales: { cash_session_id: session.id, status: Sale.statuses[:paid] })
          .where(status: Payment.statuses[:received])

        counts = payments.group(:method).count

        payments.group(:method).sum(:amount).map do |method, amount|
          {
            method: method,
            amount: amount,
            payments_count: counts.fetch(method, 0)
          }
        end
      end
    end
  end
end
