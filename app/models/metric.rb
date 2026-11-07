class Metric < ApplicationRecord
  include NodeDB::Timeseries

  self.primary_key = nil

  # The collection declares its TIME_KEY column as `timestamp`, the name
  # `NodeDB::SQL::Timeseries` filters on. `ts` is the user-facing accessor
  # and always returns a Time: the native transport hands the attribute
  # back as `[microseconds]`, and native decoding is on hold upstream of
  # this app.
  def ts
    value = self[:timestamp]
    value.is_a?(Array) ? Time.at(0, value.first, :usec).utc : value
  end

  # Example usage:
  #   Metric.since(1.hour.ago).where(host: "web-01")
  #   Metric.until_time(Time.current).order(:timestamp)
end
