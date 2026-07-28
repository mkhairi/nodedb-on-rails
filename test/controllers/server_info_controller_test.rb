require "test_helper"

class ServerInfoControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /server_info returns 200" do
    get server_info_path
    assert_response :success
    assert_match(/NodeDB server/, response.body)
  end

  test "GET /server_info renders all ops SHOW cards" do
    get server_info_path
    assert_response :success
    ["STATS", "METRICS", "MEMORY", "ROLES", "TENANT 0", "TENANTS", "USERS", "GRAPH STATS"].each do |cmd|
      assert_match(/SHOW #{cmd}/, response.body, "expected SHOW #{cmd} card")
    end
  end

  test "GET /server_info lists the default tenant and superuser" do
    get server_info_path
    assert_response :success
    assert_match(/superuser/, response.body)
    assert_match(/default/, response.body)
  end

  test "GET /server_info renders no empty-ops banner on either transport" do
    get server_info_path
    refute_match(/STATS \/ METRICS \/ MEMORY \/ ROLES are empty/, response.body)
  end

  test "GET /server_info reports the NodeDB version against the 0.4 floor" do
    get server_info_path
    assert_response :success

    # The card shows the NodeDB version, not the PostgreSQL compatibility
    # level SHOW server_version leads with ("15.0 (NodeDB 0.4.0)").
    assert_match(/NodeDB version/, response.body)
    assert_match(/minimum 0\.4\.0/, response.body)

    version = ActiveRecord::Base.connection.nodedb_version
    if Gem::Version.new(version) >= Gem::Version.new("0.4.0")
      assert_match(/supported/, response.body)
      refute_match(/below 0\.4\.0/, response.body)
    else
      assert_match(/below 0\.4\.0/, response.body)
    end
  end

  test "GET /server_info lists what the adapter compensates for" do
    get server_info_path
    assert_response :success
    assert_match(/Adapter compensations/, response.body)
    assert_match(/current_database/, response.body)
    assert_match(/ar_advisory_locks/, response.body)
  end

  test "GET /server_info does not run the DDL probe unless asked" do
    get server_info_path
    assert_response :success
    assert_match(/Run DDL probe/, response.body)
    refute_match(/DDL healthy/, response.body)
  end

  test "GET /server_info?ddl_probe=1 round-trips a throwaway collection" do
    get server_info_path(ddl_probe: 1)
    assert_response :success
    assert_match(/DDL healthy/, response.body)

    # The probe cleans up after itself.
    leftovers = ActiveRecord::Base.connection.collections.grep(/\A__ddl_probe_/)
    assert_empty leftovers, "probe left collections behind: #{leftovers.inspect}"
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
