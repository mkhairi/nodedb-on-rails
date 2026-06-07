class Metric < ApplicationRecord
  include NodeDB::Timeseries

  self.primary_key = nil

  # NodeDB silently renames the TIME_KEY column to `timestamp` on
  # projection regardless of the migration-declared name (`ts` here).
  # INSERTs against the original column still work, but `SELECT *`
  # returns the column as `timestamp` and `SELECT ts` projects null.
  # The SQL builder side already accommodates this — see
  # `NodeDB::SQL::Timeseries.time_bucket`, which hardcodes `timestamp`
  # as the column name. Surface the renamed column under the
  # user-facing `ts` accessor so views and controllers can keep
  # reading `m.ts`. `alias_attribute :ts, :timestamp` fails because
  # `timestamp` isn't in the AR-declared column set (NodeDB
  # projects it at query time, not at DESCRIBE time), so read it out
  # of the attributes hash directly.
  def ts
    self[:timestamp] || attributes["timestamp"]
  end

  # Example usage:
  #   Metric.since(1.hour.ago).where(host: "web-01")
  #   Metric.select(Metric.time_bucket("5 minutes", column: :ts)).group("bucket")
  #   Metric.until_time(Time.current).order(:ts)
end
