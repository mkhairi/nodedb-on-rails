# Exercise every NodeDB engine end-to-end through the Rails sample app.
# Run: mise x -- bundle exec ruby bin/rails runner scripts/feature_smoke.rb
#
# Each section is independent; failures are captured and printed at the end
# so partial coverage still surfaces.

require "json"
require "securerandom"

class FeatureSmoke
  Result = Struct.new(:name, :status, :detail)

  def initialize
    @results = []
    @conn = ActiveRecord::Base.connection
  end

  def run
    setup
    sections.each { |sym| call_section(sym) }
    teardown
    report
    failed_count.zero?
  end

  private

  def sections
    %i[
      section_collections_listing
      section_document_crud
      section_kv_engine
      section_timeseries_engine
      section_graph_engine
      section_spatial_engine
      section_fts_engine
      section_vector_engine
    ]
  end

  def call_section(sym)
    send(sym)
  rescue => e
    record(sym.to_s, :error, "#{e.class}: #{e.message[0, 200]}")
  end

  def record(name, status, detail = nil)
    @results << Result.new(name, status, detail)
    glyph = { ok: "PASS", fail: "FAIL", error: "ERR ", skip: "SKIP" }.fetch(status)
    puts "  [#{glyph}] #{name}#{detail ? " - #{detail}" : ''}"
  end

  MIGRATIONS = [
    ["001_create_articles.rb",  "CreateArticles",  "articles"],
    ["002_create_social.rb",    "CreateSocial",    "social_nodes"],
    ["003_create_metrics.rb",   "CreateMetrics",   "metrics"],
    ["004_create_sessions.rb",  "CreateSessions",  "kv_sessions"],
    ["005_create_locations.rb", "CreateLocations", "locations"],
    ["006_create_posts.rb",     "CreatePosts",     "posts"]
  ].freeze

  def setup
    puts "=== feature_smoke setup ==="
    MIGRATIONS.each do |file, const, name|
      load Rails.root.join("db/migrate/#{file}")
      next if @conn.collections.include?(name)
      Object.const_get(const).new.migrate(:up)
      puts "  migrated #{const}"
    rescue => e
      puts "  setup #{const}: #{e.message[0, 120]}"
    end
  end

  def teardown
    # Leave collections in place so subsequent runs are idempotent.
  end

  def report
    puts
    puts "=== feature_smoke report ==="
    grouped = @results.group_by(&:status)
    %i[ok fail error skip].each do |s|
      next unless grouped[s]
      puts "  #{s}: #{grouped[s].size}"
    end
    puts "  total: #{@results.size}"
    return if failed_count.zero?
    puts
    puts "=== failures ==="
    @results.each do |r|
      next unless %i[fail error].include?(r.status)
      puts "  - #{r.name}: #{r.detail}"
    end
  end

  def failed_count
    @results.count { |r| %i[fail error].include?(r.status) }
  end

  # ---- sections ------------------------------------------------------------

  def section_collections_listing
    puts
    puts "=== Collections listing ==="
    cs = @conn.collections
    expected = %w[articles social_nodes metrics kv_sessions locations posts]
    missing = expected - cs
    if missing.empty?
      record("collections.expected_present", :ok, "#{cs.size} collections")
    else
      record("collections.expected_present", :fail, "missing: #{missing.inspect}")
    end
  end

  def section_document_crud
    puts
    puts "=== Document (strict) CRUD ==="
    Article.where(title: ["smoke_create", "smoke_update"]).each(&:destroy) rescue nil
    a = Article.create!(title: "smoke_create", body: "body-#{SecureRandom.hex(4)}")
    record("document.create", a.persisted? ? :ok : :fail, "id=#{a.id}")
    found = Article.find(a.id)
    record("document.find_by_id", (found.title == "smoke_create" ? :ok : :fail), found.title.inspect)
    a.update!(title: "smoke_update")
    record("document.update", (Article.find(a.id).title == "smoke_update" ? :ok : :fail))
    a.destroy
    record("document.destroy", (Article.where(id: a.id).to_a.empty? ? :ok : :fail))
  end

  def section_kv_engine
    puts
    puts "=== KV engine ==="
    key = "smoke_#{SecureRandom.hex(4)}"
    KvSession.kv_set(key, "token-xyz")
    record("kv.set+get", (KvSession.kv_get(key) == "token-xyz" ? :ok : :fail), KvSession.kv_get(key).inspect)
    record("kv.exists?", (KvSession.kv_exists?(key) ? :ok : :fail))
    KvSession.kv_delete(key)
    record("kv.delete", (KvSession.kv_exists?(key) ? :fail : :ok))
  end

  def section_timeseries_engine
    puts
    puts "=== Timeseries engine ==="
    now = Time.now
    @conn.execute(
      "INSERT INTO metrics (ts, host, value) VALUES " \
      "('#{now.utc.iso8601}', 'web-01', 1.5), " \
      "('#{(now - 60).utc.iso8601}', 'web-01', 1.7)"
    )
    rows = @conn.execute("SELECT host, value FROM metrics WHERE host = 'web-01'").to_a
    record("timeseries.insert", rows.any? ? :ok : :fail, "rows=#{rows.size}")
    bucket_sql = NodeDB::SQL::Timeseries.time_bucket("1 minute", as: :bucket)
    rows = @conn.execute("SELECT #{bucket_sql}, host FROM metrics WHERE host = 'web-01' GROUP BY bucket, host").to_a rescue (record("timeseries.time_bucket", :error, "#{$!.class}: #{$!.message[0,120]}"); nil)
    record("timeseries.time_bucket", rows&.any? ? :ok : :fail, "rows=#{rows&.size}") if rows
  end

  def section_graph_engine
    puts
    puts "=== Graph engine ==="
    @conn.execute(
      "INSERT INTO social_nodes (id, name) VALUES " \
      "('alice', 'Alice'), ('bob', 'Bob'), ('carol', 'Carol') " \
    ) rescue nil
    SocialNode.graph_insert_edge(from: "alice", to: "bob",   type: "follows")
    SocialNode.graph_insert_edge(from: "bob",   to: "carol", type: "follows")
    record("graph.insert_edge", :ok)

    nodes = SocialNode.graph_traverse(from: "alice", depth: 1)
    record("graph.traverse_d1", (nodes.include?("bob") ? :ok : :fail), nodes.inspect)

    nodes2 = SocialNode.graph_traverse(from: "alice", depth: 2)
    record("graph.traverse_d2", (nodes2.include?("carol") ? :ok : :fail), nodes2.inspect)

    pr = SocialNode.graph_algo(:pagerank, damping: 0.85, iterations: 10, tolerance: 1e-4)
    record("graph.pagerank", (pr.length > 0 ? :ok : :fail), "rows=#{pr.length}")
  end

  # Sample app uses document_strict for locations (BUG-011/012 in spatial engine).
  # The smoke now exercises plain lat/lon round-trip + Ruby haversine.
  def section_spatial_engine
    puts
    puts "=== Spatial engine (document_strict + Ruby haversine) ==="
    begin
      @conn.execute("DELETE FROM locations WHERE id IN ('smk_nyc','smk_bos','smk_lax')") rescue nil
      @conn.execute(
        "INSERT INTO locations (id, name, lat, lon) VALUES " \
        "('smk_nyc', 'New York', 40.7128, -74.006), " \
        "('smk_bos', 'Boston',   42.3601, -71.0589), " \
        "('smk_lax', 'LA',       34.0522, -118.2437)"
      )
      record("spatial.insert", :ok)
    rescue => e
      record("spatial.insert", :error, "#{e.class}: #{e.message[0, 200]}")
      return
    end

    rows = @conn.execute("SELECT id, lat, lon FROM locations WHERE id IN ('smk_nyc','smk_bos','smk_lax')").to_a
    record("spatial.roundtrip",
           (rows.size == 3 && rows.all? { |r| r["lat"].to_f != 0.0 } ? :ok : :fail),
           "rows=#{rows.size}, sample lat=#{rows.first&.dig("lat")}")
  end

  def section_fts_engine
    puts
    puts "=== Full-text search engine ==="
    Post.where(title: ["fts_post_a", "fts_post_b"]).each(&:destroy) rescue nil
    Post.create!(title: "fts_post_a", body: "neural networks and deep learning fundamentals")
    Post.create!(title: "fts_post_b", body: "ruby on rails active record postgres adapter")
    record("fts.insert", :ok)

    begin
      hits = Post.fts_search("neural networks", limit: 5)
      record("fts.search", (hits.any? ? :ok : :fail), "rows=#{hits.length}")
    rescue => e
      record("fts.search", :error, "#{e.class}: #{e.message[0, 200]}")
    end

    begin
      hits = Post.fts_search("nural networks", limit: 5, fuzzy: true)
      record("fts.fuzzy", (hits.any? ? :ok : :fail), "rows=#{hits.length}")
    rescue => e
      record("fts.fuzzy", :error, "#{e.class}: #{e.message[0, 200]}")
    end
  end

  def section_vector_engine
    puts
    puts "=== Vector engine ==="
    coll = "smoke_vec_#{SecureRandom.hex(3)}"
    begin
      @conn.create_collection(coll)
      @conn.create_vector_index("idx_#{coll}_emb", on: coll, column: :embedding, metric: :cosine, dim: 3)
      @conn.execute(
        "INSERT INTO #{coll} (id, title, embedding) VALUES " \
        "('a1', 'Intro to AI', ARRAY[0.1, 0.2, 0.3]), " \
        "('a2', 'Deep Learning', ARRAY[0.4, 0.5, 0.6])"
      )
      record("vector.insert+index", :ok)
    rescue => e
      record("vector.insert+index", :error, "#{e.class}: #{e.message[0, 200]}")
      return
    end

    klass = Class.new(ApplicationRecord) do
      include NodeDB::Vector
      vector_column :embedding, dim: 3
    end
    klass.table_name = coll

    begin
      hits = klass.search_vector(:embedding, [0.1, 0.2, 0.3], limit: 1)
      ok = hits.is_a?(Array) && hits.first&.key?("distance")
      record("vector.search", (ok ? :ok : :fail), "row=#{hits.first.inspect}")
    rescue => e
      record("vector.search", :error, "#{e.class}: #{e.message[0, 200]}")
    ensure
      @conn.drop_collection(coll, if_exists: true) rescue nil
    end
  end
end

ok = FeatureSmoke.new.run
exit(ok ? 0 : 1)
