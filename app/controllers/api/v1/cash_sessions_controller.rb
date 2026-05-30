module Api
  module V1
    class CashSessionsController < ApplicationController
      def index
        require_permission!("cash_sessions.read")

        sessions = CashSession.includes(:user, cash_register: :branch)
          .order(opened_at: :desc)
        sessions = apply_filters(sessions)

        render json: { cash_sessions: sessions.limit(params.fetch(:limit, 100)).map { |session| serialize_cash_session(session) } }
      end

      def show
        require_permission!("cash_sessions.read")

        session = CashSession.includes(:user, cash_register: :branch).find(params[:id])
        render json: { cash_session: serialize_cash_session(session) }
      end

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
          user_name: session.user.full_name,
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

      def apply_filters(sessions)
        sessions = sessions.where(status: CashSession.statuses[params[:status]]) if params[:status].present?
        sessions = sessions.where(cash_register_id: params[:cash_register_id]) if params[:cash_register_id].present?
        sessions = sessions.where(user_id: params[:user_id]) if params[:user_id].present?
        sessions = sessions.where(opened_at: date_range) if params[:from].present? || params[:to].present?
        sessions = sessions.joins(:cash_register).where(cash_registers: { branch_id: params[:branch_id] }) if params[:branch_id].present?
        sessions
      end

      def date_range
        from = params[:from].present? ? Time.zone.parse(params[:from]) : Time.zone.local(1970, 1, 1)
        to = params[:to].present? ? Time.zone.parse(params[:to]) : Time.zone.now

        from..to
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
