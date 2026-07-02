require "test_helper"

# Bitemporal demo collection. Reads are plain ActiveRecord on current
# upstream; writes go through AuditLog.record! (raw autocommit INSERT)
# because AR's transaction-wrapped save is silently lost on bitemporal
# collections (BUG-024, issue #72).
class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /audit_logs renders current entries and version history" do
    get audit_logs_path
    assert_response :success
    assert_match(/BITEMPORAL/, response.body)
    assert_match(/Version history/, response.body)
  end

  test "POST /audit_logs records an entry readable through the model" do
    marker = "test_#{SecureRandom.hex(4)}"
    post audit_logs_path, params: { actor: marker, action_name: "created", target: "/t" }
    assert_redirected_to audit_logs_path

    entries = AuditLog.where(actor: marker).to_a
    assert_equal 1, entries.size
    assert_equal "created", entries.first.action

    versions = AuditLog.versions.select { |v| v["actor"] == marker }
    assert_operator versions.size, :>=, 1
    assert versions.all? { |v| v.key?("_ts_system") }
  end
end
