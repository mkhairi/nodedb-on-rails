# NodeDB On Rails

> ## ⚠️ ALPHA DEMO — DO NOT USE IN PRODUCTION
>
> Depends on `activerecord-nodedb-adapter` (**`0.1.0.alpha.9`**) and
> `nodedb-ruby` (**`0.1.0.alpha.6`**), both **experimental and never
> tested in production**. This app exists solely as an end-to-end smoke
> test for the adapter stack.
>
> Run on disposable data only — NodeDB's current upstream loses
> document-collection contents across daemon restarts (see *Operating
> notes* below).

End-to-end demo proving [`activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) works against the
Rails 8.x request → controller → view → ActiveRecord → NodeDB stack,
over both the pgwire and native transports.

## Companion packages

| Repo | Role |
| ---- | ---- |
| [`mkhairi/nodedb-ruby`](https://github.com/mkhairi/nodedb-ruby) | core — pgwire + native connections, type map, SQL builders |
| [`mkhairi/activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) | Rails ActiveRecord adapter (this app's primary dependency) |
| [`mkhairi/sequel-nodedb-adapter`](https://github.com/mkhairi/sequel-nodedb-adapter) | Sequel adapter — Dataset CRUD, DDL + engine helpers |
| [`mkhairi/nodedb-on-rails`](https://github.com/mkhairi/nodedb-on-rails) | **this app** — Rails 8 sample exercising every NodeDB engine |

## What the demo covers

| Page | Engine / surface |
| ---- | ---------------- |
| `/articles`, `/posts` | document_strict CRUD + full-text search (`NodeDB::FullTextSearch`) |
| `/locations` (+ map) | spatial writes via geometry constructors, haversine reads |
| `/social_nodes` | graph — edges, traversal, PageRank (`NodeDB::Graph`) |
| `/metrics` | timeseries + `time_bucket` aggregates (`NodeDB::Timeseries`) |
| `/embeddings` | vector search (`NodeDB::Vector`) |
| `/kv_sessions` | KV engine (`NodeDB::KV`) |
| `/audit_logs` | bitemporal collection — plain AR writes + `NodeDB::Bitemporal` time-travel reads |
| `/tenants` | multi-tenancy — tenant provisioning + per-connection isolation playground |
| `/server_info` | connection, adapter, migrations, collections, ops `SHOW` commands |

## Stack

| Layer    | Version |
| -------- | ------- |
| Ruby     | 4.0.1 (mise-managed) |
| Rails    | 8.1.3 |
| Puma     | 8.0.1 |
| Adapter  | `activerecord-nodedb-adapter` 0.1.0.alpha.9 |
| Core lib | `nodedb-ruby` 0.1.0.alpha.6 |
| NodeDB   | local source build (`../nodedb`, upstream `main`), pgwire `127.0.0.1:6432`, native `:6433` |

## Layout

```
nodedb-on-rails/
├── Gemfile                        # rails ~> 8.1, propshaft, puma; Gemfile.local for path gems
├── config/
│   ├── routes.rb                  # one resource per engine demo (see table above)
│   └── database.yml               # adapter: nodedb; transport/port/db via NODEDB_* env
├── app/
│   ├── controllers/               # articles, posts, locations, social_nodes, metrics,
│   │                              # embeddings, kv_sessions, audit_logs, tenants, server_info
│   ├── models/                    # one model per engine + Tenant/TenantSession pair
│   └── views/                     # Tabler-based pages, one folder per demo
├── db/migrate/                    # 001-009 — engine-aware create_* helpers per collection
├── scripts/feature_smoke.rb       # 33-check end-to-end engine smoke (both transports)
└── lib/tasks/test_both_transports.rake
```

## Setup

NodeDB must be running. The adapter pulls the auto-generated superuser
password from `~/.local/share/nodedb/.superuser_password`.

### Clone + standard setup

```bash
git clone git@github.com:mkhairi/nodedb-on-rails.git
cd nodedb-on-rails

# Bundle pulls the NodeDB gems from GitHub (alpha; not on rubygems yet).
bundle install

# Bootstrap: creates schema_migrations + ar_internal_metadata,
# runs all migrations, records each version, dumps db/schema.rb.
# Idempotent — safe to re-run.
bundle exec ruby bin/setup

# (Optional) seed sample data across every engine
bundle exec ruby bin/rails runner db/seeds.rb

# Boot
bundle exec rails server -p 3737 -b 127.0.0.1
```

Visit <http://127.0.0.1:3737/>.

### Transports: pgwire (default) vs native

The adapter speaks two transports. `database.yml` is env-driven and
defaults to **pgwire**:

| Env | Transport | Port | Use for |
| --- | --------- | ---- | ------- |
| _(default)_ | pgwire (libpq) | 6432 | setup, migrations, full app |
| `NODEDB_TRANSPORT=native` | NodeDB binary, no libpq | 6433 | runtime, working engines |

```bash
# Setup / migrations run over either transport (default pgwire).
bundle exec ruby bin/setup

# Run the app over the native binary protocol (no libpq):
NODEDB_TRANSPORT=native bundle exec rails server -p 3737 -b 127.0.0.1
```

The native transport is at **full result-shape parity** with pgwire on
current upstream (retested 2026-07-05): `feature_smoke` passes 33/33
on both, and the minitest suite is green on both legs
(`rake test:both_transports`). pgwire remains the documented primary
transport — the hand-rolled native client will be replaced by
NodeDB's official SDK once one ships. `/server_info` shows the active
transport.

### Operating notes (current upstream)

- **Daemon restarts lose document-collection contents** (upstream
  durability bug, tracked in the [adapter's bug tracker][ar-bugs] —
  the critical entry in `docs/KNOWN_ISSUES.md`): after any restart,
  wipe the data dir and re-run `bin/setup` + seeds.
- Dev and test environments share the default `nodedb` database
  (databases created via `CREATE DATABASE` are unusable upstream).
- Rapid one-off connections can hit transient
  `Password authentication failed` rejections with correct
  credentials — retry after ~1s; pooled Rails connections are
  unaffected.

[ar-bugs]: https://github.com/mkhairi/activerecord-nodedb-adapter/issues?q=%22%5Bupstream%3ANodeDB%5D%22

### Monorepo development setup

If you have the sister gem repos checked out alongside this one and want
`bundle install` to pick up your local edits without a `git push` round
trip, drop a `Gemfile.local` (gitignored) at the project root:

```ruby
# Gemfile.local
gem "nodedb-ruby",                 path: "../path/to/nodedb-ruby"
gem "activerecord-nodedb-adapter", path: "../path/to/activerecord-nodedb-adapter"
```

The main `Gemfile` evaluates this file when present and falls back to the
GitHub `git:` sources otherwise. Either way the adapter works the same.

## CRUD walkthrough (verified via curl)

```bash
# CREATE
LOC=$(curl -sS -i -X POST http://127.0.0.1:3737/articles \
  -d "article[title]=NodeDB+rocks&article[body]=Rails+8.1+%2B+pgwire" \
  | awk -F': ' '/^location/ {print $2}' | tr -d '\r\n')

# READ
curl -sS "$LOC"

# UPDATE  (Rails uses _method to spoof PATCH on form-encoded POST)
ID=$(echo "$LOC" | grep -oE '[a-f0-9-]{36}')
curl -sS -X POST "http://127.0.0.1:3737/articles/$ID" \
  -d "_method=patch&article[title]=Edited"

# DELETE
curl -sS -X POST "http://127.0.0.1:3737/articles/$ID" -d "_method=delete"

# LIST
curl -sS http://127.0.0.1:3737/articles
```

All seven REST routes (index, show, new, create, edit, update, destroy) plus
`/articles/search?q=…` return the expected status codes and rendered HTML.

## NodeDB-specific adjustments

These are what the sample app does differently from a typical Postgres-backed
Rails app — and why.

### 1. `document_strict` engine instead of schemaless

A bare `create_collection :articles` creates a schemaless document
collection that **silently drops** unknown columns. Rows insert OK but
`title` / `body` come back nil because they're not part of the schema.

Use the per-engine helper from `activerecord-nodedb-adapter`:

```ruby
class CreateArticles < ActiveRecord::Migration[8.0]
  def up
    create_document_strict :articles do |t|
      t.column :id,    "TEXT PRIMARY KEY"
      t.column :title, :text
      t.column :body,  :text
    end
  end
end
```

The same shape works for all engines: `create_timeseries`,
`create_kv`, `create_columnar`, `create_spatial`,
`create_document_strict`. Pass `engine_options:` for engine-specific
WITH-clause settings (retention, compression, etc).

### 2. Qualified references — handled by the adapter

NodeDB silently matches zero rows for table-qualified column
references (`"articles"."title" = ...`), which is exactly what
ActiveRecord generates for every hash-condition. The adapter strips
the target-table qualifier from single-table statements before
dispatch, so **models need no workaround** — plain AR works:

```ruby
class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  validates :title, presence: true

  before_create { self.id ||= SecureRandom.uuid }
end
```

`where(title: ...)`, conditional counts, grouped calculations, and
AR's default `SELECT "articles".*` projection all behave normally.
(No `SERIAL`/sequences upstream — text UUID PKs via `before_create`
is the house pattern.)

### 3. Schema migrations work via the adapter

Rails normally tracks every applied migration's version in a
`schema_migrations` table; in **development** AR's `check_pending!` hook
runs on every request and raises `PendingMigrationError` if any
migration in `db/migrate/` isn't recorded. NodeDB doesn't accept
standard `CREATE TABLE`, so out of the box this hook 500s every page.

The adapter ships **NodeDB-aware** `SchemaMigration` and
`InternalMetadata` subclasses that use
`CREATE COLLECTION ... WITH (engine='document_strict')` plus
NodeDB-safe read/write shapes. Effect:

- `config/environments/development.rb` keeps the Rails default
  `migration_error: :page_load` — no override needed.
- `bin/setup` (provided here) creates both tracking collections, runs
  every migration, and records the versions. Idempotent.
- `rails db:migrate` / `db:rollback` work end-to-end, including the
  schema dump.

```bash
mise x -- bundle exec ruby bin/setup
# ==> Creating schema_migrations + ar_internal_metadata
# ==> Running 001_create_articles.rb
# ...
# Done. Applied versions: ["001", "002", ..., "009"]
```

After running `bin/setup`, every page in dev serves normally and
`schema_migrations` lives as a real NodeDB collection (`SHOW
COLLECTIONS` lists it). To inspect manually:

```ruby
ActiveRecord::Base.connection_pool.schema_migration.versions
# => ["001", "002", ..., "009"]

ActiveRecord::Base.connection_pool.internal_metadata[:environment]
# => "development"
```

### 4. `database.yml` reads NodeDB's auto-generated password

```yaml
default: &default
  adapter:  nodedb
  host:     localhost
  port:     6432
  database: nodedb
  username: nodedb
  password: <%= ENV.fetch("NODEDB_PASSWORD") {
    File.read(File.expand_path("~/.local/share/nodedb/.superuser_password")).strip rescue ""
  } %>
```

## Known issues

NodeDB-side quirks the stack works around (and the ones it can't) are
tracked centrally: per-bug reproductions live in the
[adapter's issue tracker][ar-bugs] (titles prefixed
`[upstream:NodeDB] BUG-NNN`), and the user-facing rollup is the
adapter's [`docs/KNOWN_ISSUES.md`](https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/KNOWN_ISSUES.md).
The three that shape day-to-day use of this demo are summarised under
*Operating notes* above.

## Test results

Verified against upstream `main` (2026-07-05), both transports:

- `scripts/feature_smoke.rb` — **33/33** over pgwire AND native
  (every engine end-to-end, including the tenants isolation proof)
- `rake test:both_transports` — **37 runs, 0 failures** on both legs
- Adapter RSpec suite — **92 examples, 0 failures**
- CRUD walkthrough — all 7 REST verbs pass against a live NodeDB build
