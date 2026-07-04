class MetricsController < ApplicationController
  def index
    @metrics = Metric.all.to_a.sort_by { |m| m.ts.to_s }.reverse.first(50)
    @buckets = bucketed_averages
  rescue => e
    @error   = e.message
    @metrics ||= []
    @buckets ||= []
  end

  def create
    # Raw INSERT: AR's wrapped insert into a timeseries collection trips
    # NodeDB's MVCC ("could not serialize access due to concurrent
    # update"); a direct statement is the pattern used by db/seeds.rb.
    conn = ActiveRecord::Base.connection
    conn.execute(
      "INSERT INTO metrics (ts, host, value) VALUES (" \
      "#{conn.quote(Time.now.utc.iso8601)}, " \
      "#{conn.quote(params[:host].presence || 'web-01')}, " \
      "#{params[:value].to_f})"
    )
    redirect_to metrics_path, notice: "Metric recorded."
  rescue => e
    redirect_to metrics_path, alert: "Insert failed: #{e.message}"
  end

  private

  # AVG()/GROUP over a time_bucket — works on both transports since
  # NodeDB's response-shaping rework. Fails soft to an empty table on
  # a stricter build rather than raising.
  def bucketed_averages
    sql = "SELECT #{Metric.time_bucket('1 minute', as: :bucket)}, " \
          "host, AVG(value) AS avg_value " \
          "FROM metrics GROUP BY bucket, host"
    ActiveRecord::Base.connection.execute(sql).to_a
  rescue StandardError
    []
  end
end
