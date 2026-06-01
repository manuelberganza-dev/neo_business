require "test_helper"
require "tmpdir"

module Api
  module V1
    class OcrDocumentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @store = Store.create!(
          name: "OCR Store",
          legal_name: "OCR Store S.A. de C.V.",
          nit: "0614-070707-107-0",
          status: :active
        )

        ActsAsTenant.with_tenant(@store) do
          @branch = Branch.create!(store: @store, code: "MAIN", name: "Main", status: :active)
        end

        @user = User.create!(
          store: @store,
          branch: @branch,
          email: "ocr@test.local",
          full_name: "OCR User",
          password: "password123",
          password_confirmation: "password123"
        )

        role = Role.find_or_create_by!(name: "admin")
        ActsAsTenant.with_tenant(@store) do
          UserRole.create!(store: @store, user: @user, role: role)
        end

        @headers = {
          "Authorization" => "Bearer #{Warden::JWTAuth::UserEncoder.new.call(@user, :user, nil).first}"
        }
      end

      teardown do
        ActsAsTenant.current_tenant = nil
      end

      test "scans an uploaded invoice photo with Gemini and saves a local copy" do
        Dir.mktmpdir("ocr-photos") do |dir|
          with_ocr_photo_path(dir) do
            image = Tempfile.new([ "factura", ".jpg" ])
            image.binmode
            image.write("fake-jpeg-bytes")
            image.rewind

            fake_client = FakeGeminiClient.new(gemini_payload)

            with_fake_gemini_client(fake_client) do
              post "/api/v1/mobile/ocr/scan",
                params: {
                  scan: {
                    photo: Rack::Test::UploadedFile.new(image.path, "image/jpeg", original_filename: "factura.jpg")
                  }
                },
                headers: @headers
            end

            assert_response :success
            body = response.parsed_body
            assert_equal "CCF", body.dig("ocr", "document_type")
            assert_equal "Proveedor OCR", body.dig("ocr", "supplier", "name")
            assert_equal 11.3, body.dig("ocr", "total")
            assert File.exist?(File.join(dir, body.dig("photo", "reference")))
            assert_equal "image/jpeg", fake_client.calls.first.fetch(:mime_type)
            assert File.exist?(fake_client.calls.first.fetch(:image_path))
          ensure
            image&.close!
          end
        end
      end

      test "saves verified OCR data in the database" do
        Dir.mktmpdir("ocr-photos") do |dir|
          with_ocr_photo_path(dir) do
            File.binwrite(File.join(dir, "verified.jpg"), "copy")

            post "/api/v1/mobile/ocr/documents",
              params: {
                ocr_document: gemini_payload.merge(photo_reference: "verified.jpg")
              },
              headers: @headers,
              as: :json

            assert_response :created
            document_id = response.parsed_body.dig("ocr_document", "id")

            ActsAsTenant.with_tenant(@store) do
              document = OcrDocument.find(document_id)
              assert_equal "CCF", document.document_type
              assert_equal "Proveedor OCR", document.supplier_name
              assert_equal 1, document.ocr_document_items.count
              assert_equal File.join(dir, "verified.jpg"), document.photo_path
            end
          end
        end
      end

      private

      class FakeGeminiClient
        attr_reader :calls

        def initialize(payload)
          @payload = payload
          @calls = []
        end

        def extract(image_path:, mime_type:)
          @calls << { image_path: image_path, mime_type: mime_type }
          @payload
        end
      end

      def with_ocr_photo_path(path)
        previous = Rails.application.config.x.ocr.photo_storage_path
        Rails.application.config.x.ocr.photo_storage_path = path
        yield
      ensure
        Rails.application.config.x.ocr.photo_storage_path = previous
      end

      def with_fake_gemini_client(client)
        singleton = class << Ocr::GeminiClient; self; end
        previous = Ocr::GeminiClient.method(:new)
        singleton.define_method(:new) { |*args, **kwargs| client }
        yield
      ensure
        singleton.define_method(:new) { |*args, **kwargs| previous.call(*args, **kwargs) }
      end

      def gemini_payload
        {
          document_type: "CCF",
          document_number: "DTE-001",
          control_number: "DTE-01-0001",
          generation_code: "ABC-123",
          issued_at: "2026-06-01T10:00:00-06:00",
          supplier: {
            name: "Proveedor OCR",
            nit: "0614-111111-111-0",
            nrc: "123456-7",
            activity: "Venta",
            address: "San Salvador"
          },
          customer: {
            name: "Cliente Demo",
            nit: "0614-222222-222-0",
            nrc: "765432-1"
          },
          currency: "USD",
          subtotal: 10,
          tax: 1.3,
          discount: 0,
          total: 11.3,
          items: [
            {
              description: "Producto OCR",
              quantity: 1,
              unit_price: 10,
              tax_rate: 0.13,
              total: 11.3
            }
          ],
          confidence: 0.92,
          warnings: []
        }
      end
    end
  end
end
