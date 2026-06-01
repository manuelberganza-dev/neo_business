module Ocr
  class ScanService
    def initialize(gemini_client: GeminiClient.new, photo_storage: PhotoStorage.new)
      @gemini_client = gemini_client
      @photo_storage = photo_storage
    end

    def call(upload:)
      photo = @photo_storage.save(upload)
      raw_payload = @gemini_client.extract(image_path: photo.fetch(:path), mime_type: photo.fetch(:mime_type))
      data = PayloadNormalizer.new(raw_payload).call

      {
        ocr: data,
        photo: {
          reference: photo.fetch(:reference),
          original_filename: photo.fetch(:original_filename)
        }
      }
    end
  end
end
