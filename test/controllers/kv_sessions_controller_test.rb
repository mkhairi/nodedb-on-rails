require "test_helper"

class KvSessionsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /kv_sessions returns 200" do
    # Native KV reads collapse to KeyError "value" (BUG-018), and the
    # index page fetches all rows.
    skip_native "KV read shape mismatch on native (BUG-018, issue #45)"

    get kv_sessions_path
    assert_response :success
  end
end
