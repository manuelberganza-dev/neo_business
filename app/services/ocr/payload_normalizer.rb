module Ocr
  class PayloadNormalizer
    DOCUMENT_TYPES = %w[CCF Factura Ticket DTE Otro].freeze

    def initialize(payload)
      @payload = payload.to_h.deep_stringify_keys
    end

    def call
      {
        document_type: document_type,
        document_number: string("document_number"),
        control_number: string("control_number"),
        generation_code: string("generation_code"),
        issued_at: string("issued_at"),
        supplier: {
          name: nested_string("supplier", "name"),
          nit: nested_string("supplier", "nit"),
          nrc: nested_string("supplier", "nrc"),
          activity: nested_string("supplier", "activity"),
          address: nested_string("supplier", "address")
        },
        customer: {
          name: nested_string("customer", "name"),
          nit: nested_string("customer", "nit"),
          nrc: nested_string("customer", "nrc")
        },
        currency: string("currency") || "USD",
        subtotal: decimal("subtotal").to_f,
        tax: decimal("tax").to_f,
        discount: decimal("discount").to_f,
        total: decimal("total").to_f,
        items: items,
        confidence: confidence,
        warnings: Array(@payload["warnings"]).map(&:to_s)
      }
    end

    private

    def document_type
      value = string("document_type")
      DOCUMENT_TYPES.include?(value) ? value : "Otro"
    end

    def items
      rows = Array(@payload["items"]).map do |item|
        item = item.to_h.deep_stringify_keys

        {
          description: item["description"].presence,
          quantity: numeric(item["quantity"]),
          unit_price: numeric(item["unit_price"]),
          tax_rate: numeric(item["tax_rate"], 0.13),
          total: numeric(item["total"])
        }
      end

      rows.presence || [
        {
          description: nil,
          quantity: 0,
          unit_price: 0,
          tax_rate: 0.13,
          total: 0
        }
      ]
    end

    def string(key)
      @payload[key].presence&.to_s
    end

    def nested_string(parent, key)
      @payload[parent].to_h[key].presence&.to_s
    end

    def decimal(key)
      to_decimal(@payload[key])
    end

    def numeric(value, default = 0)
      to_decimal(value, default).to_f
    end

    def confidence
      value = numeric(@payload["confidence"])
      value.clamp(0, 1)
    end

    def to_decimal(value, default = 0)
      BigDecimal(value.presence.to_s)
    rescue ArgumentError, NoMethodError
      BigDecimal(default.to_s)
    end
  end
end
