require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = false
  config.action_controller.allow_forgery_protection = false

  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :rescuable
  config.active_record.dump_schema_after_migration = false

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.i18n.raise_on_missing_translations = false

  # Surface real errors in test output instead of HTML-formatted dumps.
  config.exceptions_app = nil
end
