require "test_helper"

class ServerInfoControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /server_info returns 200" do
    get server_info_path
    assert_response :success
    assert_match(/NodeDB server/, response.body)
  end

  test "GET /server_info renders all five ops SHOW cards" do
    get server_info_path
    assert_response :success
    %w[STATS METRICS MEMORY ROLES TENANT].each do |cmd|
      assert_match(/SHOW #{cmd}/, response.body, "expected SHOW #{cmd} card")
    end
  end

  test "GET /server_info renders no BUG-022 banner on either transport" do
    get server_info_path
    refute_match(/BUG-022 banner|STATS \/ METRICS \/ MEMORY \/ ROLES are empty/, response.body)
  end

  test "GET /server_info shows the active transport badge" do
    get server_info_path
    if native?
      assert_match(/native/, response.body)
    else
      assert_match(/pgwire/, response.body)
    end
  end
end
