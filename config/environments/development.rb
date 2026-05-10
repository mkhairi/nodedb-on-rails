require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.action_controller.perform_caching = false
  config.action_controller.enable_fragment_cache_logging = true
  config.cache_store = :memory_store
  config.action_dispatch.show_exceptions = :all
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.action_view.annotate_rendered_view_with_filenames = true
  config.action_controller.raise_on_missing_callback_actions = true
  config.hosts.clear
  config.assets.compile = true if config.respond_to?(:assets)
end
