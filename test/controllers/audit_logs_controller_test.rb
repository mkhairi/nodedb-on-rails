require "test_helper"

# Bitemporal demo collection. NodeDB v0.3.0 accepts the migration and
# the INSERT, but every SELECT shape returns zero rows (BUG-021, issue
# #63). The controller still renders 200 with an empty table + banner.
class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /audit_logs returns 200 (BUG-021: reads stay empty)" do
    get audit_logs_path
    assert_response :success
    # The danger banner is always present until upstream lands the
    # bitemporal read path.
    assert_match(/BITEMPORAL|BUG-021|bitemporal/, response.body)
  end
end
