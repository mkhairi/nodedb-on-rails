# Seed data for the NodeDB On Rails sample app.
# Run: bin/rails runner db/seeds.rb
#
# The fixtures describe one imaginary product — a developer platform
# with a knowledge base, a community forum, edge sites, a team graph,
# host telemetry, a semantic-search catalog, session state, uploaded
# reports and an audit trail — so each engine holds data belonging to
# the same story rather than an isolated toy row.
#
# Idempotent: every section clears its own prior fixtures before
# inserting. Safe to re-run.

require "securerandom"

conn = ActiveRecord::Base.connection

# NodeDB rejects a multi-key predicate DELETE ("OLLP dependent-read
# exhausted 5 retries ... consider rephrasing as a static-key UPDATE"),
# so clear one primary key at a time. Clearing the whole collection
# rather than just this file's ids keeps a re-seed from stacking new
# fixtures on top of an older generation's.
# Some engines have no usable reset. A graph collection rejects every
# DELETE once it carries an edge (BUG-065), a timeseries collection
# reports "DELETE 0" and removes nothing (BUG-066), and DROP puts the
# name into a retention window that blocks recreating it immediately —
# so those sections seed once and then skip, rather than stacking a
# second copy on every run. Start from a fresh data directory (or
# `UNDROP COLLECTION <name>` after a manual drop) to re-seed them.
def already_seeded?(conn, collection, predicate = nil)
  sql = "SELECT id FROM #{collection}"
  sql += " WHERE #{predicate}" if predicate
  conn.execute(sql).to_a.any?
rescue StandardError
  false
end

def clear_collection(model)
  model.unscoped.from(model.table_name).select("id").to_a.each do |row|
    model.where(id: row["id"] || row.id).delete_all
  end
end

puts "==> articles (document_strict) — knowledge base"
KB = [
  ["kb_quickstart",   "Quickstart: your first deployment",
   "Install the CLI, authenticate with a project token, and run `platform deploy`. " \
   "The first deploy provisions a project, a production environment and a default domain."],
  ["kb_environments", "Environments and promotion",
   "Every project gets production and preview environments. Preview environments are " \
   "created per pull request and torn down when the branch merges. Promotion copies the " \
   "build artifact rather than rebuilding, so what you tested is what ships."],
  ["kb_secrets",      "Managing secrets",
   "Secrets are encrypted at rest and injected as environment variables at boot. " \
   "Rotating a secret triggers a rolling restart; the old value stays readable to " \
   "running instances until they cycle."],
  ["kb_regions",      "Choosing a region",
   "Pick the region closest to your database, not your users — the round trip that " \
   "matters is app-to-database. Static assets are served from every edge site regardless."],
  ["kb_scaling",      "Autoscaling rules",
   "Instances scale on request concurrency, not CPU. The default target is 40 concurrent " \
   "requests per instance. Background workers scale on queue depth instead."],
  ["kb_databases",    "Connecting a database",
   "Connection strings live in the environment. Use a pooler for serverless workloads: " \
   "each instance holds a small pool, and instance count changes faster than a database " \
   "can accept new backends."],
  ["kb_logging",      "Structured logging",
   "Anything written to stdout is captured. Emit JSON objects with a `level` key and the " \
   "log viewer will index the fields for filtering."],
  ["kb_metrics",      "Metrics and alerts",
   "Host and application gauges are retained for 30 days at full resolution. Alerts " \
   "evaluate on a five-minute window to avoid paging on a single slow request."],
  ["kb_rollbacks",    "Rolling back a bad deploy",
   "Every deploy keeps its artifact. `platform rollback` repoints traffic at the previous " \
   "build without a rebuild, so recovery time is a health check, not a CI run."],
  ["kb_migrations",   "Running database migrations",
   "Run migrations as a release command, before traffic shifts. Keep them backward " \
   "compatible for one deploy so a rollback does not land on a schema it cannot read."],
  ["kb_webhooks",     "Webhooks and retries",
   "Webhook deliveries retry with exponential backoff for 24 hours. Respond 2xx quickly " \
   "and do the work asynchronously — the delivery timeout is 10 seconds."],
  ["kb_limits",       "Platform limits",
   "Request bodies cap at 100 MB, response streaming has no cap, and a single build may " \
   "run for 45 minutes. Background jobs have no wall-clock limit."]
].freeze

clear_collection(Article)
KB.each { |id, title, body| Article.create!(id: id, title: title, body: body) }

puts "==> posts (FTS) — community forum"
FORUM = [
  ["post_vector_search", "Vector search on a budget",
   "We replaced a managed vector service with an approximate nearest neighbour index " \
   "next to our primary data. Recall stayed above 95% and the cosine similarity numbers " \
   "matched within noise. The win was operational: one system to back up, not two."],
  ["post_hotwire",       "Hotwire in production, one year on",
   "Turbo Drive and Stimulus carried the whole application. No build step, no hydration " \
   "bugs, and the JavaScript bundle never grew past 40 KB. Turbo Streams over WebSocket " \
   "handle the live pages."],
  ["post_pg_tuning",     "Postgres tuning that actually mattered",
   "shared_buffers and work_mem got all the attention, but the fix was a missing index " \
   "on a foreign key and a connection pooler. Measure before turning knobs."],
  ["post_k8s_regret",    "We moved off Kubernetes",
   "Three engineers cannot run a control plane and a product. Boring virtual machines " \
   "with a deploy script recovered a week per month of maintenance time."],
  ["post_oncall",        "Making on-call humane",
   "Every page must be actionable. We deleted two thirds of our alerts, and mean time to " \
   "recovery went down, because the remaining pages were read instead of dismissed."],
  ["post_graph_model",   "Modelling a social graph without a graph database",
   "Adjacency lists in a relational table carried us to a million edges. Traversal depth, " \
   "not edge count, is what eventually pushed us to a real graph engine."],
  ["post_timeseries",    "Downsampling telemetry",
   "Raw samples at one second, five-minute rollups after a week, hourly after a month. " \
   "Storage dropped 90% and no dashboard noticed."],
  ["post_search_ux",     "Full-text search is a UX problem",
   "Stemming and fuzzy matching fixed the recall complaints. Ranking fixed the rest: " \
   "users read three results, so result four might as well not exist."],
  ["post_migrations",    "Zero-downtime migrations, honestly",
   "Expand, backfill, contract. The backfill is the dangerous part — batch it, throttle " \
   "it, and make it resumable, because it will be interrupted."],
  ["post_caching",       "Cache invalidation, the easy half",
   "Key by content hash and the invalidation problem mostly evaporates. What remains is " \
   "deciding how stale is acceptable, which is a product question."],
  ["post_costs",         "Where the cloud bill actually goes",
   "Egress and idle capacity, in that order. Compute was a third of the bill and the only " \
   "line item anyone had optimised."],
  ["post_rails_scale",   "Rails at a few thousand requests per second",
   "The framework was never the bottleneck. Database round trips per request was the " \
   "number that mattered, and it fell by half after one afternoon with the query log."]
].freeze

clear_collection(Post)
FORUM.each { |id, title, body| Post.create!(id: id, title: title, body: body) }

puts "==> locations (document_strict + Ruby haversine) — edge sites"
SITES = {
  "site_kul" => ["Kuala Lumpur",   3.1390,  101.6869],
  "site_sin" => ["Singapore",      1.3521,  103.8198],
  "site_hkg" => ["Hong Kong",     22.3193,  114.1694],
  "site_nrt" => ["Tokyo",         35.6762,  139.6503],
  "site_syd" => ["Sydney",       -33.8688,  151.2093],
  "site_bom" => ["Mumbai",        19.0760,   72.8777],
  "site_fra" => ["Frankfurt",     50.1109,    8.6821],
  "site_lhr" => ["London",        51.5074,   -0.1278],
  "site_cdg" => ["Paris",         48.8566,    2.3522],
  "site_iad" => ["Ashburn",       39.0438,  -77.4874],
  "site_sfo" => ["San Francisco", 37.7749, -122.4194],
  "site_gru" => ["Sao Paulo",    -23.5505,  -46.6333]
}.freeze

clear_collection(Location)
SITES.each { |id, (name, lat, lon)| Location.create!(id: id, name: name, lat: lat, lon: lon) }

puts "==> social_nodes + edges (graph) — team follow graph"
PEOPLE = {
  "alice" => "Alice Tan",    "bob"   => "Bob Ismail",
  "carol" => "Carol Wong",   "dave"  => "Dave Kumar",
  "erin"  => "Erin Fitzroy", "frank" => "Frank Osei",
  "grace" => "Grace Lim",    "hana"  => "Hana Sato",
  "ivan"  => "Ivan Petrov",  "julia" => "Julia Costa",
  "kenji" => "Kenji Mori",   "lena"  => "Lena Novak"
}.freeze

# Three clusters joined by a few bridge edges, so PageRank has
# structure to find and traversal depth is more than a straight line.
FOLLOWS = [
  %w[alice bob], %w[alice carol], %w[bob carol], %w[carol alice],
  %w[bob dave], %w[dave alice], %w[carol dave],
  %w[erin frank], %w[frank grace], %w[grace erin], %w[frank erin],
  %w[hana ivan], %w[ivan julia], %w[julia hana], %w[ivan kenji],
  %w[kenji lena], %w[lena hana], %w[julia kenji],
  # bridges between clusters — these are what PageRank rewards
  %w[dave erin], %w[carol erin], %w[erin hana], %w[alice hana],
  %w[kenji alice], %w[grace julia]
].freeze

if already_seeded?(conn, "social_nodes", "id = 'alice'")
  puts "    skipped — already seeded (DELETE is rejected once a collection has edges)"
else
  PEOPLE.each { |id, name| SocialNode.create!(id: id, name: name) }
  FOLLOWS.each { |from, to| SocialNode.graph_insert_edge(from: from, to: to, type: "follows") }
end

puts "==> metrics (timeseries) — 48h of host telemetry"
# The TIME_KEY column is `timestamp` and carries epoch milliseconds.
# Raw autocommit INSERTs on purpose: AR's transaction-wrapped insert
# into a timeseries collection trips NodeDB's MVCC.
HOSTS = {
  "web-01" => { base: 0.35, swing: 0.30, noise: 0.05 },
  "web-02" => { base: 0.30, swing: 0.28, noise: 0.05 },
  "db-01"  => { base: 0.62, swing: 0.15, noise: 0.03 }
}.freeze

HOUR_MS = 3_600_000
now_ms  = (Time.now.utc.to_i / 3600) * 3600 * 1000
rng     = Random.new(20_260_728) # fixed seed: same shape on every run

metric_rows = HOSTS.flat_map do |host, shape|
  48.downto(1).map do |hours_ago|
    at   = now_ms - (hours_ago * HOUR_MS)
    hour = Time.at(at / 1000).utc.hour
    # Diurnal curve, busiest mid-afternoon UTC, plus a little noise.
    load = shape[:base] +
           shape[:swing] * Math.sin((hour - 3) / 24.0 * 2 * Math::PI).abs +
           rng.rand(-shape[:noise]..shape[:noise])
    [at, host, load.clamp(0.01, 0.99).round(3)]
  end
end

if already_seeded?(conn, "metrics", "host = 'web-01'")
  puts "    skipped — already seeded (DELETE against a timeseries collection is a no-op)"
  metric_rows = []
else
  metric_rows.each_slice(50) do |slice|
    values = slice.map { |at, host, value| "(#{at}, #{conn.quote(host)}, #{value})" }.join(", ")
    conn.execute("INSERT INTO metrics (timestamp, host, value) VALUES #{values}")
  end
end

puts "==> embeddings (vector engine, dim 3) — semantic catalog"
Embedding::SAMPLES.each do |s|
  conn.execute("DELETE FROM embeddings WHERE id = #{conn.quote(s[:id])}") rescue nil
  Embedding.insert_vector(id: s[:id], title: s[:title], vec: s[:vec])
end

puts "==> kv_sessions — session and config state"
KvSession.all.each { |row| KvSession.kv_delete(row.key) }
{
  "session:u42"        => '{"user_id":42,"email":"alice@example.com","role":"admin"}',
  "session:u77"        => '{"user_id":77,"email":"bob@example.com","role":"member"}',
  "feature:flags"      => '{"new_ui":true,"beta_search":true,"legacy_export":false}',
  "ratelimit:api:u42"  => '{"window":"2026-07-28T12:00Z","count":143,"limit":1000}',
  "ratelimit:api:u77"  => '{"window":"2026-07-28T12:00Z","count":12,"limit":1000}',
  "cache:pricing:v3"   => '{"starter":0,"team":49,"scale":199}',
  "job:nightly_rollup" => '{"last_run":"2026-07-28T03:00Z","status":"ok","duration_s":412}',
  "banner:maintenance" => '{"active":false,"message":""}'
}.each { |key, value| KvSession.kv_set(key, value) }

puts "==> stored_files (metadata in document_strict, body in kv)"
REPORTS = [
  ["incident-2026-07-14.md", "text/markdown",
   "# Incident 2026-07-14\n\nElevated error rate on web-02 for 18 minutes.\n" \
   "Cause: connection pool exhaustion after a deploy doubled instance count.\n" \
   "Fix: pooler max_connections raised, autoscale ceiling capped.\n"],
  ["capacity-q3.csv", "text/csv",
   "region,instances,p95_ms,monthly_usd\nap-southeast,12,180,1420\n" \
   "eu-west,8,150,980\nus-east,20,120,2310\n"],
  ["retention-policy.txt", "text/plain",
   "Telemetry: 30 days full resolution, 13 months rolled up.\n" \
   "Audit log: retained indefinitely, bitemporal.\nBuild artifacts: 90 days.\n"]
].freeze

StoredFile.all.each(&:purge!)
REPORTS.each do |filename, content_type, body|
  record = StoredFile.create!(
    filename:     filename,
    content_type: content_type,
    byte_size:    body.bytesize,
    uploaded_at:  Time.current.utc.iso8601
  )
  FileBlob.write(record.id, body)
end

puts "==> audit_logs (bitemporal) — deploy trail, two entries corrected"
TRAIL = [
  ["alice", "deploy",        "platform/api@v128",  '{"env":"production","duration_s":94}'],
  ["bob",   "rollback",      "platform/api@v127",  '{"env":"production","reason":"error rate"}'],
  ["carol", "secret.rotate", "DATABASE_URL",       '{"env":"production"}'],
  ["dave",  "user.invite",   "erin@example.com",   '{"role":"member"}'],
  ["erin",  "deploy",        "platform/web@v311",  '{"env":"preview","pr":482}'],
  ["frank", "scale",         "web-02",             '{"from":4,"to":8}'],
  ["grace", "flag.enable",   "beta_search",        '{"rollout_pct":25}'],
  ["hana",  "db.migrate",    "20260726_add_index", '{"env":"production","rows":1840000}'],
  ["ivan",  "user.suspend",  "julia@example.com",  '{"reason":"offboarding"}'],
  ["kenji", "flag.disable",  "legacy_export",      '{"rollout_pct":0}']
].freeze

if already_seeded?(conn, "audit_logs", "actor = 'alice'")
  puts "    skipped — already seeded (each delete would leave a tombstone version behind)"
else
  trail_start = Time.current.utc - (3 * TRAIL.size).hours
  TRAIL.each_with_index do |(actor, action, target, context), i|
    AuditLog.record!(actor: actor, action: action, target: target, context: context,
                     recorded_at: (trail_start + (i * 3).hours).iso8601)
  end

  # Two corrections, so the bitemporal history has something to show:
  # the current state of these rows differs from their first version.
  AuditLog.where(actor: "frank", action: "scale").each do |log|
    log.update!(context: '{"from":4,"to":12,"note":"corrected: ceiling raised again"}')
  end
  AuditLog.where(actor: "grace", action: "flag.enable").each do |log|
    log.update!(context: '{"rollout_pct":100,"note":"corrected: full rollout same day"}')
  end
end

puts
puts "Seed counts:"
puts "  articles      : #{Article.unscoped.from(Article.table_name).select('id').to_a.size}"
puts "  posts         : #{Post.unscoped.from(Post.table_name).select('id').to_a.size}"
puts "  locations     : #{Location.unscoped.from(Location.table_name).select('id').to_a.size}"
puts "  social_nodes  : #{SocialNode.unscoped.from(SocialNode.table_name).select('id').to_a.size} " \
     "(#{FOLLOWS.size} follow edges)"
puts "  metrics       : #{conn.execute('SELECT id FROM metrics').to_a.size} " \
     "(#{metric_rows.size} seeded across #{HOSTS.size} hosts)"
puts "  embeddings    : #{Embedding::SAMPLES.size} seeded (schemaless; not scan-countable)"
puts "  kv_sessions   : #{conn.execute('SELECT key FROM kv_sessions').to_a.size}"
puts "  stored_files  : #{StoredFile.unscoped.from(StoredFile.table_name).select('id').to_a.size}"
puts "  audit_logs    : #{AuditLog.unscoped.from(AuditLog.table_name).select('id').to_a.size} " \
     "(#{AuditLog.versions.size} versions)"
puts
puts "Done."
