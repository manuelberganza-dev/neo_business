module Api
  module V1
    class BaseCrudController < ApplicationController
      def index
        require_permission!("#{collection_name}.read")

        records = apply_filters(resource_scope)
        render json: { collection_name => records.map { |record| serialize_resource(record) } }
      end

      def show
        require_permission!("#{collection_name}.read")

        render json: { resource_name => serialize_resource(resource_scope.find(params[:id])) }
      end

      def create
        require_permission!("#{collection_name}.write")

        record = resource_scope.create!(resource_params)
        after_save(record)

        render json: { resource_name => serialize_resource(record) }, status: :created
      end

      def update
        require_permission!("#{collection_name}.write")

        record = resource_scope.find(params[:id])
        record.update!(resource_params)
        after_save(record)

        render json: { resource_name => serialize_resource(record) }
      end

      def destroy
        require_permission!("#{collection_name}.write")

        record = resource_scope.find(params[:id])
        deactivate_or_destroy(record)

        render json: { resource_name => serialize_resource(record.reload) }
      end

      private

      def model_class
        raise NotImplementedError
      end

      def permitted_attributes
        raise NotImplementedError
      end

      def collection_name
        model_class.model_name.plural
      end

      def resource_name
        model_class.model_name.singular
      end

      def resource_scope
        model_class.all
      end

      def resource_params
        params.require(resource_name).permit(*permitted_attributes)
      end

      def apply_filters(scope)
        scope.order(created_at: :desc).limit(params.fetch(:limit, 100))
      end

      def serialize_resource(record)
        record.as_json
      end

      def after_save(_record)
      end

      def deactivate_or_destroy(record)
        if record.has_attribute?(:active)
          record.update!(active: false)
        elsif record.has_attribute?(:status) && record.class.respond_to?(:statuses) && record.class.statuses.key?("inactive")
          record.update!(status: :inactive)
        else
          record.destroy!
        end
      end
    end
  end
end
