# Minitest setup for nodedb-on-rails.
#
# These tests run against the live local NodeDB daemon — there is no
# separate test database. The suite assumes the same seed data that
# `bin/setup` and `db/seeds.rb` install. Tests are isolation-light:
# they read shared data and only insert into ephemeral collections or
# rows that they clean up themselves.
#
# To run the full suite under both transports:
#   bin/rails test                          # pgwire (default)
#   NODEDB_TRANSPORT=native bin/rails test  # native binary protocol
#
# Or use the rake convenience task that runs both back-to-back:
#   bin/rails test:both_transports
ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "socket"

require_relative "support/transport_helpers"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    include TransportHelpers

    # Default `Time.zone` so timeseries-related comparisons are
    # deterministic across machines that may have different system
    # zones configured.
    self.use_transactional_tests = false
  end
end

class ActionDispatch::IntegrationTest
  include TransportHelpers
end
