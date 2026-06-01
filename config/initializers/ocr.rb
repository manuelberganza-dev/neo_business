Rails.application.config.x.ocr.photo_storage_path = ENV.fetch(
  "OCR_PHOTO_STORAGE_PATH",
  "C:/Users/Manuel Berganza/Desktop/fotos_rails"
)
Rails.application.config.x.ocr.gemini_model = ENV.fetch("GEMINI_MODEL", "gemini-flash-latest")
Rails.application.config.x.ocr.gemini_models = ENV.fetch(
  "GEMINI_MODELS",
  Rails.application.config.x.ocr.gemini_model
).split(",").map(&:strip).reject(&:blank?)
Rails.application.config.x.ocr.gemini_timeout = ENV.fetch("GEMINI_TIMEOUT", "18").to_i
Rails.application.config.x.ocr.gemini_max_retries = ENV.fetch("GEMINI_MAX_RETRIES", "0").to_i
Rails.application.config.x.ocr.gemini_retry_delay = ENV.fetch("GEMINI_RETRY_DELAY", "0.5").to_f
