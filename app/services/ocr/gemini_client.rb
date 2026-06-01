require "base64"
require "json"
require "net/http"

module Ocr
  class GeminiClient
    PROMPT = <<~PROMPT.freeze
      Extrae los datos fiscales y comerciales de esta imagen de una factura, CCF, ticket o DTE de El Salvador.

      Devuelve exclusivamente JSON valido con esta estructura exacta:
      {
        "document_type": "CCF | Factura | Ticket | DTE | Otro",
        "document_number": null,
        "control_number": null,
        "generation_code": null,
        "issued_at": null,
        "supplier": {
          "name": null,
          "nit": null,
          "nrc": null,
          "activity": null,
          "address": null
        },
        "customer": {
          "name": null,
          "nit": null,
          "nrc": null
        },
        "currency": "USD",
        "subtotal": 0,
        "tax": 0,
        "discount": 0,
        "total": 0,
        "items": [
          {
            "description": null,
            "quantity": 0,
            "unit_price": 0,
            "tax_rate": 0.13,
            "total": 0
          }
        ],
        "confidence": 0,
        "warnings": []
      }

      Usa numeros sin simbolos de moneda. Si un campo no se puede leer, usa null o 0 segun corresponda.
      Para DTE de El Salvador, prioriza codigo de generacion, numero de control, sello/numero de documento, fecha de emision, NIT/NRC y totales.
      Agrega advertencias breves en "warnings" cuando haya baja legibilidad, totales inconsistentes o campos importantes faltantes.
    PROMPT

    def initialize(
      api_key: ENV["GEMINI_API_KEY"],
      model: Rails.application.config.x.ocr.gemini_model,
      timeout: Rails.application.config.x.ocr.gemini_timeout
    )
      @api_key = api_key.to_s
      @model = model
      @timeout = timeout
    end

    def extract(image_path:, mime_type:)
      raise ApplicationError.new("GEMINI_API_KEY is not configured", code: "gemini_api_key_missing", status: :service_unavailable) if @api_key.blank?

      response = perform_request(image_path: image_path, mime_type: mime_type)
      parse_response(response)
    end

    private

    def perform_request(image_path:, mime_type:)
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-goog-api-key"] = @api_key
      request.body = JSON.generate(request_payload(image_path: image_path, mime_type: mime_type))

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: @timeout, open_timeout: @timeout) do |http|
        http.request(request)
      end
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise ApplicationError.new("Gemini OCR request failed: #{error.message}", code: "gemini_request_failed", status: :bad_gateway)
    end

    def request_payload(image_path:, mime_type:)
      {
        contents: [
          {
            role: "user",
            parts: [
              {
                inline_data: {
                  mime_type: mime_type,
                  data: Base64.strict_encode64(File.binread(image_path))
                }
              },
              { text: PROMPT }
            ]
          }
        ],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.1
        }
      }
    end

    def parse_response(response)
      body = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        message = body.dig("error", "message") || "Gemini OCR request failed"
        raise ApplicationError.new(message, code: "gemini_request_failed", status: :bad_gateway)
      end

      text = Array(body.dig("candidates", 0, "content", "parts")).filter_map { |part| part["text"] }.join
      raise ApplicationError.new("Gemini returned an empty OCR response", code: "gemini_empty_response", status: :bad_gateway) if text.blank?

      JSON.parse(clean_json_text(text))
    rescue JSON::ParserError => error
      raise ApplicationError.new("Gemini OCR response was not valid JSON: #{error.message}", code: "gemini_invalid_json", status: :bad_gateway)
    end

    def clean_json_text(text)
      text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
    end
  end
end
