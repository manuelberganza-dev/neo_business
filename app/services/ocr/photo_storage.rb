module Ocr
  class PhotoStorage
    ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
    EXTENSIONS = {
      "image/jpeg" => ".jpg",
      "image/png" => ".png",
      "image/webp" => ".webp",
      "image/heic" => ".heic",
      "image/heif" => ".heif"
    }.freeze

    def self.root
      Pathname.new(Rails.application.config.x.ocr.photo_storage_path)
    end

    def self.path_for_reference(reference)
      filename = File.basename(reference.to_s)
      path = root.join(filename).expand_path
      root_path = root.expand_path.to_s

      return path if path.to_s.start_with?(root_path)

      raise ApplicationError.new("Invalid OCR photo reference", code: "invalid_photo_reference")
    end

    def save(upload)
      raise ApplicationError.new("Photo is required", code: "photo_required") if upload.blank?

      mime_type = upload.content_type.to_s
      unless ALLOWED_CONTENT_TYPES.include?(mime_type)
        raise ApplicationError.new("Unsupported photo content type", code: "unsupported_photo_content_type")
      end

      FileUtils.mkdir_p(self.class.root)

      extension = EXTENSIONS.fetch(mime_type)
      filename = "#{Time.current.strftime("%Y%m%d%H%M%S%6N")}-#{SecureRandom.hex(8)}#{extension}"
      path = self.class.root.join(filename)

      upload.rewind if upload.respond_to?(:rewind)
      File.binwrite(path, upload.read)

      {
        path: path.to_s,
        reference: filename,
        mime_type: mime_type,
        original_filename: upload.original_filename
      }
    end
  end
end
