Rails.application.config.x.ocr.photo_storage_path = ENV.fetch(
  "OCR_PHOTO_STORAGE_PATH",
  "C:/Users/Manuel Berganza/Desktop/fotos_rails"
)
Rails.application.config.x.ocr.gemini_model = ENV.fetch("GEMINI_MODEL", "gemini-flash-latest")
Rails.application.config.x.ocr.gemini_timeout = ENV.fetch("GEMINI_TIMEOUT", "30").to_i
