module CashSessions
  class OpenService
    def initialize(store:, user:)
      @store = store
      @user = user
    end

    def call(cash_register_id:, opening_amount:)
      CashSession.transaction do
        cash_register = CashRegister.lock.find(cash_register_id)
        ensure_same_store!(cash_register)
        ensure_register_available!(cash_register)

        session = CashSession.create!(
          store: @store,
          cash_register: cash_register,
          user: @user,
          opening_amount: opening_amount,
          status: :open,
          opened_at: Time.current
        )

        cash_register.update!(status: :in_use)
        audit!("cash_session.open", session, opening_amount: opening_amount)
        session
      end
    end

    private

    def ensure_same_store!(cash_register)
      return if cash_register.store_id == @store.id

      raise ActiveRecord::RecordNotFound
    end

    def ensure_register_available!(cash_register)
      return if cash_register.available?

      raise ApplicationError.new("Cash register is not available", code: "cash_register_not_available")
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
  end
end
