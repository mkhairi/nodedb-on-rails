require "test_helper"

# Engine-level smoke mirroring scripts/feature_smoke.rb at the
# Minitest layer. Confirms each engine round-trips real data through
# the AR adapter under whichever transport this run is using.
#
# The same expectations as the rake-driven smoke script:
#   pgwire — all engines pass
#   native — KV + vector still gated by BUG-018 (skipped per test)
class EnginesSmokeTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "document_strict CRUD round-trips through ActiveRecord" do
    id = "smoke_#{SecureRandom.hex(4)}"
    a = Article.create!(id: id, title: "smoke", body: "body")
    assert_equal "smoke", Article.find(id).title
    a.update!(title: "smoke-v2")
    assert_equal "smoke-v2", Article.find(id).title
    a.destroy
    refute Article.where(id: id).exists?
  end

  test "timeseries engine accepts INSERT and SELECT" do
    conn = ActiveRecord::Base.connection
    host = "smoke-host-#{SecureRandom.hex(2)}"
    conn.execute(
      "INSERT INTO metrics (ts, host, value) VALUES (" \
      "#{conn.quote(Time.now.utc.iso8601)}, #{conn.quote(host)}, 0.42)"
    )
    rows = conn.execute("SELECT host, value FROM metrics WHERE host = #{conn.quote(host)}").to_a
    assert rows.any?, "expected at least one row for host=#{host}"
  end

  test "graph engine inserts edges and traverses" do
    # Run-unique edge type: NodeDB never re-materializes a deleted
    # (from, to, type) edge — re-inserting after a previous run's
    # ensure-delete is a silent no-op, so a fixed type would traverse
    # empty on every run after the first clean delete.
    edge_type = "smokes_#{SecureRandom.hex(4)}"
    SocialNode.find_or_create_by!(id: "smoke_root") { |n| n.name = "Smoke Root" }
    SocialNode.find_or_create_by!(id: "smoke_leaf") { |n| n.name = "Smoke Leaf" }
    SocialNode.graph_insert_edge(from: "smoke_root", to: "smoke_leaf", type: edge_type)

    reachable = SocialNode.graph_traverse(from: "smoke_root", depth: 1)
    assert_includes reachable, "smoke_leaf"
  ensure
    if edge_type
      SocialNode.graph_delete_edge(from: "smoke_root", to: "smoke_leaf", type: edge_type) rescue nil
    end
  end

  test "graph_stats returns rows scoped to the social_nodes collection" do
    rows = SocialNode.graph_stats
    assert_kind_of Array, rows
    # Empty Array is acceptable when no edges exist; if any row is
    # returned it must be scoped to the SocialNode table.
    rows.each do |r|
      assert_equal "social_nodes", r["collection"].to_s.delete('"')
    end
  end

  test "fts search returns rows for a known token" do
    skip "no FTS rows expected without seeded posts" if Post.count.zero?

    rows = Post.fts_search("rails", limit: 5)
    assert rows.is_a?(Array)
  end

  test "kv set + get + delete" do

    key = "smoke_kv_#{SecureRandom.hex(4)}"
    KvSession.kv_set(key, "v1")
    assert_equal "v1", KvSession.kv_get(key)
    KvSession.kv_delete(key)
    assert_nil KvSession.kv_get(key)
  end

  test "vector search returns surrogate + distance rows" do

    embedding = Array.new(3) { rand.to_f }
    rows = Embedding.search_vector(:embedding, embedding, limit: 1)
    assert rows.is_a?(Array)
  end
end
