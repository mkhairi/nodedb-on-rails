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

    # Pgwire reports the attribute under the renamed key; native
    # currently strips most columns from document-backed reads
    # (BUG-018) so the assertion is transport-aware.
    if native?
      # Native may return nil for the renamed key — only assert the
      # reader doesn't raise.
      assert_nothing_raised { m.ts }
    else
      assert_kind_of String, m.ts
      assert_match(/\A\d+\z/, m.ts)
    end
  end
end
