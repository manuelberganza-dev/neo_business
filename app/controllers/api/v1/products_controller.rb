module Api
  module V1
    class ProductsController < BaseCrudController
      include Rails.application.routes.url_helpers

      private

      def model_class
        Product
      end

      def permitted_attributes
        [
          :category_id,
          :unit_id,
          :brand_id,
          :sku,
          :barcode,
          :name,
          :description,
          :cost,
          :price,
          :tax_rate,
          :track_inventory,
          :active
        ]
      end

      def resource_params
        super.merge(store: current_store)
      end

      def apply_filters(scope)
        scope = scope.includes(:category, :unit, :brand)
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where("sku LIKE ?", "%#{params[:sku]}%") if params[:sku].present?
        scope = scope.where(barcode: params[:barcode]) if params[:barcode].present?
        scope.order(:name).limit(params.fetch(:limit, 100))
      end

      def after_save(record)
        record.image.attach(params[:product][:image]) if params.dig(:product, :image).present?
      end

      def serialize_resource(product)
        {
          id: product.id,
          store_id: product.store_id,
          category_id: product.category_id,
          category_name: product.category&.name,
          unit_id: product.unit_id,
          unit_code: product.unit&.code,
          brand_id: product.brand_id,
          brand_name: product.brand&.name,
          sku: product.sku,
          barcode: product.barcode,
          name: product.name,
          description: product.description,
          cost: product.cost,
          price: product.price,
          tax_rate: product.tax_rate,
          track_inventory: product.track_inventory,
          active: product.active,
          image_attached: product.image.attached?,
          image_url: product.image.attached? ? rails_blob_path(product.image, only_path: true) : nil,
          created_at: product.created_at,
          updated_at: product.updated_at
        }
      end
    end
  end
end
