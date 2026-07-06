# Static intro (root) + in-app docs for the demo. No DB dependency —
# these pages must render even when the daemon is down.
class PagesController < ApplicationController
  GEMS = %w[nodedb-ruby activerecord-nodedb-adapter pg rails].freeze

  def home
    @gem_versions = GEMS.index_with { |name| Gem.loaded_specs[name]&.version&.to_s }
    @daemon_up    = daemon_up?
  end

  def docs
  end

  private

  def daemon_up?
    ActiveRecord::Base.connection_pool.with_connection(&:active?)
  rescue StandardError
    false
  end
end
