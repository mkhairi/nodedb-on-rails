require "test_helper"

# Regression coverage for the `Metric#ts` reader: NodeDB silently
# renames every TIME_KEY column to `timestamp` on projection, so
# `m.ts` reads the renamed attribute. Without the explicit reader on
# the model the view raised ActiveModel::MissingAttributeError on
# every page load.
class MetricsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /metrics returns 200 without MissingAttributeError" do
    get metrics_path
    assert_response :success
    refute_match(/MissingAttributeError|missing attribute 'ts'/, response.body)
  end

  test "Metric#ts reads the upstream-renamed timestamp attribute" do
    m = Metric.limit(1).to_a.first
    skip "no metrics seeded yet" if m.nil?

    # Epoch ms; pgwire projects it as a TEXT string, native as Integer.
    assert_match(/\A\d+\z/, m.ts.to_s)
    assert_operator m.ts.to_i, :>, 0
  end

  test "GET /metrics/live samples the sys gauges and returns chart series" do
    get live_metrics_path
    assert_response :success

    body = JSON.parse(response.body)
    names = body["series"].map { |s| s["name"] }
    assert_equal %w[sys.cpu_load sys.disk_pct sys.mem_mb], names.sort

    # Each tick writes one point per gauge; the fresh sample must be
    # in the returned window as [epoch_ms, value] pairs.
    body["series"].each do |s|
      assert s["data"].any?, "expected points for #{s['name']}"
      ms, value = s["data"].last
      assert_kind_of Integer, ms
      assert_kind_of Numeric, value
    end
  end
end
