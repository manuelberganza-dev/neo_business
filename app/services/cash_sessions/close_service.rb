module CashSessions
  class CloseService
    def initialize(store:, user:)
      @store = store
      @user = user
    end

    def call(cash_session_id:, closing_amount:)
      session = CashSession.transaction do
        session = CashSession.lock.find(cash_session_id)
        ensure_same_store!(session)
        ensure_open!(session)

        expected_amount = session.opening_amount + payments_total(session)
        difference_amount = BigDecimal(closing_amount.to_s) - expected_amount

        session.update!(
          closing_amount: closing_amount,
          expected_amount: expected_amount,
          difference_amount: difference_amount,
          closed_at: Time.current,
          status: :closed
        )

        session.cash_register.update!(status: :available)
        audit!("cash_session.close", session, expected_amount: expected_amount, difference_amount: difference_amount)
        session
      end

      broadcast_closed(session)
      session
    end

    private

    def payments_total(session)
      Payment.joins(:sale)
        .where(sales: { cash_session_id: session.id, status: Sale.statuses[:paid] })
        .where(status: Payment.statuses[:received])
        .sum(:amount)
    end

    def ensure_same_store!(session)
      return if session.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_open!(session)
      return if session.open?

      raise ApplicationError.new("Cash session is not open", code: "cash_session_not_open")
    end

    def audit!(action, record, metadata = {})
      AuditLog.create!(
        store: @store,
        user: @user,
        action: action,
        entity: record.class.name,
        entity_id: record.id,
        metadata: metadata,
        occurred_at: Time.current
      )
    end

    def broadcast_closed(session)
      Realtime::Broadcaster.pos(@store, :cash_session_closed, {
        cash_session_id: session.id,
        cash_register_id: session.cash_register_id,
        user_id: session.user_id,
        closing_amount: session.closing_amount,
        expected_amount: session.expected_amount,
        difference_amount: session.difference_amount,
        closed_at: session.closed_at
      })
    end
  end
end
