# Seed data for the NodeDB On Rails sample app.
# Run: bin/rails runner db/seeds.rb
#
# Idempotent — each section deletes its prior fixtures (where AR is wired up)
# before inserting fresh rows. Uses AR-style models throughout, with the
# connection-level Array<Numeric> -> VECTOR quote hook (PR #21) for
# embeddings.

require "securerandom"

conn = ActiveRecord::Base.connection

puts "==> articles (document_strict)"
Article.where(id: %w[seed_a1 seed_a2 seed_a3]).delete_all
Article.create!(id: "seed_a1", title: "Introduction to AI",
                body:  "AI is transforming every industry.")
Article.create!(id: "seed_a2", title: "Deep Learning Basics",
                body:  "Neural networks learn from data.")
Article.create!(id: "seed_a3", title: "Graph Databases",
                body:  "Graphs model relationships naturally.")

puts "==> posts (FTS)"
Post.where(id: %w[seed_p1 seed_p2 seed_p3]).delete_all
Post.create!(id: "seed_p1", title: "Vector search intro",
             body:  "Approximate nearest neighbor search with cosine similarity.")
Post.create!(id: "seed_p2", title: "Hotwire on Rails",
             body:  "Turbo and Stimulus deliver SPA feel without the JavaScript build.")
Post.create!(id: "seed_p3", title: "Postgres tuning",
             body:  "shared_buffers, work_mem, and effective_cache_size are the big knobs.")

puts "==> locations (document_strict + Ruby haversine)"
Location.where(id: %w[seed_kl seed_sg seed_tk seed_ny seed_la]).delete_all
{
  "seed_kl" => ["Kuala Lumpur",   3.1390, 101.6869],
  "seed_sg" => ["Singapore",      1.3521, 103.8198],
  "seed_tk" => ["Tokyo",         35.6762, 139.6503],
  "seed_ny" => ["New York",      40.7128, -74.0060],
  "seed_la" => ["Los Angeles",   34.0522, -118.2437]
}.each do |id, (name, lat, lon)|
  Location.create!(id: id, name: name, lat: lat, lon: lon)
end

puts "==> social_nodes + edges (graph)"
SocialNode.where(id: %w[alice bob carol dave]).delete_all
SocialNode.create!(id: "alice", name: "Alice")
SocialNode.create!(id: "bob",   name: "Bob")
SocialNode.create!(id: "carol", name: "Carol")
SocialNode.create!(id: "dave",  name: "Dave")
SocialNode.graph_insert_edge(from: "alice", to: "bob",   type: "follows")
SocialNode.graph_insert_edge(from: "bob",   to: "carol", type: "follows")
SocialNode.graph_insert_edge(from: "carol", to: "dave",  type: "follows")
SocialNode.graph_insert_edge(from: "dave",  to: "alice", type: "follows")

puts "==> metrics (timeseries)"
now = Time.now.utc
[
  [now - 3600, "web-01", 0.42],
  [now - 1800, "web-01", 0.55],
  [now,        "web-01", 0.61],
  [now - 3600, "db-01",  0.80],
  [now,        "db-01",  0.75]
].each do |ts, host, value|
  conn.execute(
    "INSERT INTO metrics (ts, host, value) VALUES " \
    "(#{conn.quote(ts.iso8601)}, #{conn.quote(host)}, #{value})"
  )
end

puts "==> kv_sessions"
KvSession.kv_set("demo_session", "user_id:42")
KvSession.kv_set("feature:flags", '{"new_ui":true,"beta":false}')

puts
puts "Seed counts:"
puts "  articles      : #{Article.unscoped.from(Article.table_name).select('id').to_a.size}"
puts "  posts         : #{Post.unscoped.from(Post.table_name).select('id').to_a.size}"
puts "  locations     : #{Location.unscoped.from(Location.table_name).select('id').to_a.size}"
puts "  social_nodes  : #{SocialNode.unscoped.from(SocialNode.table_name).select('id').to_a.size}"
puts "  metrics       : #{conn.execute('SELECT id FROM metrics').to_a.size}"
puts "  kv_sessions   : #{conn.execute('SELECT key FROM kv_sessions').to_a.size}"
puts
puts "Done."
