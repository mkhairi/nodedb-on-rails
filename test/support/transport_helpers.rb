require "socket"

# Shared helpers for tests that need to (a) detect the active NodeDB
# transport, (b) skip themselves when a known upstream bug rules out a
# specific transport, or (c) reach the SHOW-command surface without
# raising on a stricter NodeDB build.
module TransportHelpers
  NATIVE = "native".freeze
  PGWIRE = "pg".freeze

  def transport
    ENV.fetch("NODEDB_TRANSPORT", PGWIRE)
  end

  def native?
    transport == NATIVE
  end

  def pgwire?
    !native?
  end

  # Mark a test as known-broken on the native transport. The skip
  # message includes the linked upstream bug so future retests are
  # easy to track down.
  def skip_native(reason)
    skip("native transport: #{reason}") if native?
  end

  # Mark a test as known-broken on pgwire. Mirror of skip_native.
  def skip_pgwire(reason)
    skip("pgwire transport: #{reason}") if pgwire?
  end

  # True only when the NodeDB pgwire port (6432) is reachable. Used
  # to skip the entire suite cleanly when the daemon isn't running.
  def nodedb_pgwire_up?
    Socket.tcp("localhost", 6432, connect_timeout: 1) { true }
  rescue StandardError
    false
  end

  def nodedb_native_up?
    Socket.tcp("localhost", 6433, connect_timeout: 1) { true }
  rescue StandardError
    false
  end

  def skip_if_daemon_down!
    skip("NodeDB pgwire :6432 unreachable") if pgwire? && !nodedb_pgwire_up?
    skip("NodeDB native :6433 unreachable") if native? && !nodedb_native_up?
  end
end
