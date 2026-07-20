require "test_helper"

class KvSessionsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /kv_sessions returns 200" do
    get kv_sessions_path
    assert_response :success
  end
end
