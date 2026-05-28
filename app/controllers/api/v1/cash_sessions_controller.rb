module Api
  module V1
    class CashSessionsController < ApplicationController
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
          user_id: session.user_id,
          opening_amount: session.opening_amount,
          closing_amount: session.closing_amount,
          expected_amount: session.expected_amount,
          difference_amount: session.difference_amount,
          status: session.status,
          opened_at: session.opened_at,
          closed_at: session.closed_at
        }
      end
    end
  end
end
