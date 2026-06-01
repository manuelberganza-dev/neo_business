module Api
  module V1
    class OcrDocumentsController < ApplicationController
      def scan
        require_permission!("purchases.write")

        result = Ocr::ScanService.new.call(upload: scan_upload)
        render json: result, status: :ok
      end

      def create
        require_permission!("purchases.write")

        document = Ocr::Documents::CreateService.new(store: current_store, user: current_user).call(ocr_document_params)
        render json: { ocr_document: serialize_ocr_document(document) }, status: :created
      end

      private

      def scan_upload
        params.dig(:scan, :photo) || params[:photo]
      end

      def ocr_document_params
        params.require(:ocr_document).permit(
          :photo_reference,
          :document_type,
          :document_number,
          :control_number,
          :generation_code,
          :issued_at,
          :currency,
          :subtotal,
          :tax,
          :discount,
          :total,
          :confidence,
          warnings: [],
          supplier: [ :name, :nit, :nrc, :activity, :address ],
          customer: [ :name, :nit, :nrc ],
          items: [ :description, :quantity, :unit_price, :tax_rate, :total ]
        ).to_h.deep_symbolize_keys
      end

      def serialize_ocr_document(document)
        {
          id: document.id,
          document_type: document.document_type,
          document_number: document.document_number,
          control_number: document.control_number,
          generation_code: document.generation_code,
          issued_at: document.issued_at,
          supplier: {
            name: document.supplier_name,
            nit: document.supplier_nit,
            nrc: document.supplier_nrc,
            activity: document.supplier_activity,
            address: document.supplier_address
          },
          customer: {
            name: document.customer_name,
            nit: document.customer_nit,
            nrc: document.customer_nrc
          },
          currency: document.currency,
          subtotal: document.subtotal.to_f,
          tax: document.tax.to_f,
          discount: document.discount.to_f,
          total: document.total.to_f,
          items: document.ocr_document_items.map do |item|
            {
              id: item.id,
              description: item.description,
              quantity: item.quantity.to_f,
              unit_price: item.unit_price.to_f,
              tax_rate: item.tax_rate.to_f,
              total: item.total.to_f
            }
          end,
          confidence: document.confidence.to_f,
          warnings: document.warnings || [],
          status: document.status,
          verified_at: document.verified_at,
          created_at: document.created_at
        }
      end
    end
  end
end
