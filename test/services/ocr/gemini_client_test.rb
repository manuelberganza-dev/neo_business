require "test_helper"

module Ocr
  class GeminiClientTest < ActiveSupport::TestCase
    test "maps Gemini high demand responses to service unavailable" do
      client = GeminiClient.new(api_key: "test-key", models: [ "gemini-flash-latest" ], max_retries: 0)
      response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
      response.instance_variable_set(:@read, true)
      response.body = {
        error: {
          message: "This model is currently experiencing high demand."
        }
      }.to_json

      error = assert_raises(ApplicationError) do
        client.send(:parse_response, response)
      end

      assert_equal "gemini_unavailable", error.code
      assert_equal :service_unavailable, error.status
    end

    test "maps Gemini rate limit responses to too many requests" do
      client = GeminiClient.new(api_key: "test-key", models: [ "gemini-flash-latest" ], max_retries: 0)
      response = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      response.instance_variable_set(:@read, true)
      response.body = {
        error: {
          message: "Quota exceeded."
        }
      }.to_json

      error = assert_raises(ApplicationError) do
        client.send(:parse_response, response)
      end

      assert_equal "gemini_rate_limited", error.code
      assert_equal :too_many_requests, error.status
    end

    test "uses default model when configured models are blank" do
      client = GeminiClient.new(api_key: "test-key", models: [ "", nil ], max_retries: 0)

      assert_equal [ "gemini-2.5-flash" ], client.instance_variable_get(:@models)
    end

    test "includes max output token limit in request payload" do
      client = GeminiClient.new(api_key: "test-key", max_output_tokens: 2048)
      payload = client.send(:request_payload, image_path: __FILE__, mime_type: "image/jpeg")

      assert_equal 2048, payload.dig(:generationConfig, :maxOutputTokens)
    end
  end
end
