# Samples three host gauges and records them into the `metrics`
# timeseries collection — the write half of the realtime chart demo.
# The `host` column doubles as the series name (sys.* prefix keeps the
# system series apart from manually recorded metrics).
#
# Raw INSERTs on purpose: AR's transaction-wrapped insert into a
# timeseries collection trips NodeDB's MVCC ("could not serialize
# access due to concurrent update"); direct autocommit statements are
# the working pattern (same as db/seeds.rb).
class SystemSampler
  SERIES = {
    "sys.cpu_load" => -> { Sys::CPU.load_avg[0].to_f },
    "sys.mem_mb"   => -> { GetProcessMem.new.mb.round(1) },
    "sys.disk_pct" => lambda {
      s = Sys::Filesystem.stat("/")
      (100.0 * (s.blocks - s.blocks_available) / s.blocks).round(1)
    }
  }.freeze

  def self.sample!
    conn = ActiveRecord::Base.connection
    now  = Time.now.utc.iso8601
    SERIES.each do |name, gauge|
      conn.execute(
        "INSERT INTO metrics (ts, host, value) VALUES (" \
        "#{conn.quote(now)}, #{conn.quote(name)}, #{gauge.call})"
      )
    end
  end

  # Last `window` of each sys.* series as ApexCharts-ready
  # [epoch_ms, value] pairs, oldest first.
  def self.series(window: 10.minutes)
    rows = Metric.since(Time.now.utc - window).to_a
    SERIES.keys.map do |name|
      # Metric#ts is the upstream-renamed TIME_KEY, already epoch ms.
      data = rows.select { |m| m.host == name }
                 .map { |m| [m.ts.to_i, m.value.to_f] }
                 .sort_by(&:first)
      { name: name, data: data }
    end
  end
end
