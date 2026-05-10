require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "propshaft"

Bundler.require(*Rails.groups)

module NodeDBSample
  class Application < Rails::Application
    config.load_defaults 8.1

    config.api_only = false
    config.eager_load = false

    config.autoload_lib(ignore: %w[assets tasks])

    config.action_controller.allow_forgery_protection = false
  end
end
