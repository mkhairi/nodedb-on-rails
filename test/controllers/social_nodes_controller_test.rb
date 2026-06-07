require "test_helper"

class SocialNodesControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /social_nodes returns 200" do
    get social_nodes_path
    assert_response :success
  end

  test "GET /social_nodes/graph renders SHOW GRAPH STATS panel + PageRank" do
    get graph_social_nodes_path
    assert_response :success
    # The graph stats panel is the v0.3.0 feature surface; the badge
    # appears only when SHOW GRAPH STATS returns a row for this
    # collection.
    assert_match(/Graph stats|PageRank/, response.body)
  end

  test "GET /social_nodes/recommend without a seed shows empty-state" do
    get recommend_social_nodes_path
    assert_response :success
    assert_match(/seed node/i, response.body)
  end

  test "GET /social_nodes/recommend with a seed returns 200" do
    # Demo seeds drop 'alice' / 'bob' / 'carol' into social_nodes.
    get recommend_social_nodes_path, params: { seed: "alice" }
    assert_response :success
  end

  test "GET /social_nodes/traverse from a known seed returns 200" do
    # Note: traverse currently has no HTML view (returns 406). The index
    # view consumes the same data via the `from`/`depth` query params.
    skip "traverse action has no dedicated HTML template — index handles it inline"
    get traverse_social_nodes_path, params: { from: "alice", depth: 2 }
    assert_response :success
  end

  test "GET /social_nodes?from=alice&depth=2 renders the inline reachable list" do
    get social_nodes_path, params: { from: "alice", depth: 2 }
    assert_response :success
  end
end
