Rails.application.config.x.ocr.photo_storage_path = ENV.fetch(
  "OCR_PHOTO_STORAGE_PATH",
  "C:/Users/Manuel Berganza/Desktop/fotos_rails"
)
Rails.application.config.x.ocr.gemini_model = ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash").presence || "gemini-2.5-flash"
Rails.application.config.x.ocr.gemini_models = (
  ENV["GEMINI_MODELS"].presence || "#{Rails.application.config.x.ocr.gemini_model},gemini-2.0-flash-lite"
).split(",").map(&:strip).reject(&:blank?)
Rails.application.config.x.ocr.gemini_timeout = ENV.fetch("GEMINI_TIMEOUT", "45").to_i
Rails.application.config.x.ocr.gemini_max_retries = ENV.fetch("GEMINI_MAX_RETRIES", "0").to_i
Rails.application.config.x.ocr.gemini_retry_delay = ENV.fetch("GEMINI_RETRY_DELAY", "0.5").to_f
Rails.application.config.x.ocr.gemini_max_output_tokens = ENV.fetch("GEMINI_MAX_OUTPUT_TOKENS", "4096").to_i
