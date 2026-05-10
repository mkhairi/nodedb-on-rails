class Metric < ApplicationRecord
  include NodeDB::Timeseries

  self.primary_key = nil

  # Example usage:
  #   Metric.since(1.hour.ago).where(host: "web-01")
  #   Metric.select(Metric.time_bucket("5 minutes", column: :ts)).group("bucket")
  #   Metric.until_time(Time.current).order(:ts)
end
