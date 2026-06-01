require "base64"
require "json"
require "net/http"

module Ocr
  class GeminiClient
    DEFAULT_MODEL = "gemini-2.5-flash"

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
      models: Rails.application.config.x.ocr.gemini_models,
      timeout: Rails.application.config.x.ocr.gemini_timeout,
      max_retries: Rails.application.config.x.ocr.gemini_max_retries,
      retry_delay: Rails.application.config.x.ocr.gemini_retry_delay,
      max_output_tokens: Rails.application.config.x.ocr.gemini_max_output_tokens
    )
      @api_key = api_key.to_s
      @models = Array(models).flat_map { |model| model.to_s.split(",") }.map(&:strip).reject(&:blank?)
      @models = [ DEFAULT_MODEL ] if @models.empty?
      @timeout = timeout
      @max_retries = [ max_retries.to_i, 0 ].max
      @retry_delay = [ retry_delay.to_f, 0 ].max
      @max_output_tokens = [ max_output_tokens.to_i, 512 ].max
    end

    def extract(image_path:, mime_type:)
      raise ApplicationError.new("GEMINI_API_KEY is not configured", code: "gemini_api_key_missing", status: :service_unavailable) if @api_key.blank?

      with_gemini_retries do |model|
        response = perform_request(model: model, image_path: image_path, mime_type: mime_type)
        parse_response(response)
      end
    end

    private

    def with_gemini_retries
      last_error = nil

      @models.each do |model|
        (@max_retries + 1).times do |attempt|
          return yield(model)
        rescue ApplicationError => error
          raise error unless retryable?(error)

          last_error = error
          sleep(@retry_delay * (attempt + 1)) if attempt < @max_retries
        end
      end

      raise last_error
    end

    def retryable?(error)
      %w[gemini_rate_limited gemini_unavailable gemini_timeout gemini_request_failed].include?(error.code)
    end

    def perform_request(model:, image_path:, mime_type:)
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-goog-api-key"] = @api_key
      request.body = JSON.generate(request_payload(image_path: image_path, mime_type: mime_type))

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: @timeout, open_timeout: @timeout) do |http|
        http.request(request)
      end
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise ApplicationError.new("Gemini OCR request timed out: #{error.message}", code: "gemini_timeout", status: :gateway_timeout)
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
          maxOutputTokens: @max_output_tokens,
          temperature: 0.1
        }
      }
    end

    def parse_response(response)
      body = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        message = body.dig("error", "message") || "Gemini OCR request failed"
        raise gemini_error(response, message)
      end

      text = Array(body.dig("candidates", 0, "content", "parts")).filter_map { |part| part["text"] }.join
      raise ApplicationError.new("Gemini returned an empty OCR response", code: "gemini_empty_response", status: :bad_gateway) if text.blank?

      JSON.parse(clean_json_text(text))
    rescue JSON::ParserError => error
      raise ApplicationError.new("Gemini OCR response was not valid JSON: #{error.message}", code: "gemini_invalid_json", status: :bad_gateway)
    end

    def gemini_error(response, message)
      case response
      when Net::HTTPTooManyRequests
        ApplicationError.new(message, code: "gemini_rate_limited", status: :too_many_requests)
      when Net::HTTPServiceUnavailable
        ApplicationError.new(message, code: "gemini_unavailable", status: :service_unavailable)
      when Net::HTTPGatewayTimeOut
        ApplicationError.new(message, code: "gemini_timeout", status: :gateway_timeout)
      else
        ApplicationError.new(message, code: "gemini_request_failed", status: :bad_gateway)
      end
    end

    def clean_json_text(text)
      text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
    end
  end
end
