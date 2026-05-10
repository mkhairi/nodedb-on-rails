Rails.application.config.secret_key_base = ENV.fetch(
  "SECRET_KEY_BASE",
  "dev_only_secret_a" * 8
)
