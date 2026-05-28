module Api
  module V1
    class MobileController < ApplicationController
      def scan_product
        require_permission!("products.read")

        product = Product.find_by!(barcode: scan_params.fetch(:barcode))

        render json: {
          product: {
            id: product.id,
            sku: product.sku,
            barcode: product.barcode,
            name: product.name,
            price: product.price,
            tax_rate: product.tax_rate,
            active: product.active
          }
        }
      end

      private

      def scan_params
        params.require(:scan).permit(:barcode)
      end
    end
  end
end
