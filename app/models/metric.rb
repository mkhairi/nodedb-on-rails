class Metric < ApplicationRecord
  include NodeDB::Timeseries

  self.primary_key = nil

  # The collection declares its TIME_KEY column as `timestamp`
  # (BUG-063: upstream used to rename any TIME_KEY column to
  # `timestamp` on projection and no longer does, so the declared name
  # has to match what the SQL builders filter on — see
  # `NodeDB::SQL::Timeseries`, which hardcodes `timestamp`). Keep the
  # user-facing `ts` accessor for views and controllers.
  # `alias_attribute :ts, :timestamp` fails because `timestamp` isn't
  # in the AR-declared column set (NodeDB projects it at query time,
  # not at DESCRIBE time), so read it out of the attributes hash.
  def ts
    self[:timestamp] || attributes["timestamp"]
  end

  # Example usage:
  #   Metric.since(1.hour.ago).where(host: "web-01")
  #   Metric.select(Metric.time_bucket("5 minutes", column: :ts)).group("bucket")
  #   Metric.until_time(Time.current).order(:ts)
end
