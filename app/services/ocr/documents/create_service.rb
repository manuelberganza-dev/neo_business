module Ocr
  module Documents
    class CreateService
      def initialize(store:, user:)
        @store = store
        @user = user
      end

      def call(attributes)
        payload = PayloadNormalizer.new(attributes).call
        photo_path = photo_path_for(attributes[:photo_reference])

        OcrDocument.transaction do
          document = OcrDocument.create!(
            store: @store,
            user: @user,
            document_type: payload[:document_type],
            document_number: payload[:document_number],
            control_number: payload[:control_number],
            generation_code: payload[:generation_code],
            issued_at: parse_time(payload[:issued_at]),
            supplier_name: payload.dig(:supplier, :name),
            supplier_nit: payload.dig(:supplier, :nit),
            supplier_nrc: payload.dig(:supplier, :nrc),
            supplier_activity: payload.dig(:supplier, :activity),
            supplier_address: payload.dig(:supplier, :address),
            customer_name: payload.dig(:customer, :name),
            customer_nit: payload.dig(:customer, :nit),
            customer_nrc: payload.dig(:customer, :nrc),
            currency: payload[:currency],
            subtotal: payload[:subtotal],
            tax: payload[:tax],
            discount: payload[:discount],
            total: payload[:total],
            confidence: payload[:confidence],
            warnings: payload[:warnings],
            raw_response: payload,
            photo_path: photo_path,
            status: :verified,
            verified_at: Time.current
          )

          payload[:items].each do |item|
            OcrDocumentItem.create!(
              store: @store,
              ocr_document: document,
              description: item[:description],
              quantity: item[:quantity],
              unit_price: item[:unit_price],
              tax_rate: item[:tax_rate],
              total: item[:total]
            )
          end

          audit!("ocr_document.create", document, total: document.total, item_count: document.ocr_document_items.count)
          document
        end
      end

      private

      def photo_path_for(reference)
        return if reference.blank?

        Ocr::PhotoStorage.path_for_reference(reference).to_s
      end

      def parse_time(value)
        Time.zone.parse(value.to_s) if value.present?
      rescue ArgumentError
        nil
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
end
