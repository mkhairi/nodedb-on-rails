# NodeDB On Rails

> ## ⚠️ ALPHA DEMO — DO NOT USE IN PRODUCTION
>
> Depends on `nodedb-ruby` and `activerecord-nodedb-adapter` at
> **`0.1.0.alpha.1`**, both **experimental and never tested in production**.
> This app exists solely as an end-to-end smoke test for the adapter stack.
>
> Run on disposable data only.

End-to-end demo proving [`activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) works against the
Rails 8.x request → controller → view → ActiveRecord → NodeDB pgwire stack.

## Companion packages

| Repo | Role |
| ---- | ---- |
| [`mkhairi/nodedb-ruby`](https://github.com/mkhairi/nodedb-ruby) | core — pgwire connection, type map, SQL builders |
| [`mkhairi/activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) | Rails ActiveRecord adapter (this app's primary dependency) |
| [`mkhairi/sequel-nodedb-adapter`](https://github.com/mkhairi/sequel-nodedb-adapter) | Sequel adapter (stub) |
| [`mkhairi/nodedb-on-rails`](https://github.com/mkhairi/nodedb-on-rails) | **this app** — Rails 8 sample exercising every NodeDB engine |

## Stack

| Layer    | Version |
| -------- | ------- |
| Ruby     | 4.0.1 (mise-managed) |
| Rails    | 8.1.3 |
| Puma     | 8.0.1 |
| Adapter  | `activerecord-nodedb-adapter` (path gem) |
| Core lib | `nodedb-ruby` (path gem) |
| NodeDB   | local source build (`../nodedb`), pgwire on `127.0.0.1:6432` |

## Layout

```
nodedb-on-rails/
├── Gemfile                            # rails ~> 8.1, propshaft, puma, path gems
├── Rakefile
├── config.ru
├── bin/{rails,rake}                   # standard Rails 8 launchers
├── config/
│   ├── boot.rb / application.rb / environment.rb
│   ├── routes.rb                      # resources :articles + :social_nodes
│   ├── database.yml                   # adapter: nodedb, port 6432, user nodedb
│   ├── environments/development.rb    # standard Rails defaults (migration_error: :page_load works)
│   └── initializers/secret_key.rb
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── articles_controller.rb     # 7 REST actions + search
│   ├── models/
│   │   ├── application_record.rb
│   │   └── article.rb                 # default_scope select unqualified cols
│   └── views/
│       ├── layouts/application.html.erb
│       └── articles/{index,show,new,edit,_form}.html.erb
└── db/migrate/
    └── 001_create_articles.rb         # CREATE COLLECTION ... document_strict
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
# Schema-tracking over native works since adapter 0.1.0.alpha.5
# (the result shim normalises the document blob).
bundle exec ruby bin/setup

# Run the app over the native binary protocol (no libpq):
NODEDB_TRANSPORT=native bundle exec rails server -p 3737 -b 127.0.0.1
```

Native runtime status (NodeDB v0.3.0 release `25040fdf`, adapter
`0.1.0.alpha.7`, retested 2026-06-07): connection, schema-tracking,
document model CRUD, timeseries, graph (traversal + pagerank), spatial
roundtrip, and FTS (search + fuzzy) all work. **KV and vector reads**
remain limited by BUG-018 (those engines' columns aren't projected
over native). `feature_smoke` parity: pgwire 21/21, native 17/19.
`/server_info` shows the active transport. See
activerecord-nodedb-adapter `docs/bugs/018`, issue #45.

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

### 2. Unqualified column projection

NodeDB's SQL parser does not resolve qualified column refs:

| SQL                                          | Result    |
| -------------------------------------------- | --------- |
| `SELECT id, title, body FROM articles`       | works     |
| `SELECT articles.id, articles.title FROM …`  | columns return nil |
| `SELECT "articles"."id" FROM "articles"`     | columns return nil |

ActiveRecord's default projection is `SELECT "articles".* FROM "articles"`,
so the model declares an unqualified `default_scope`:

```ruby
class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  default_scope { select("id, title, body") }   # unqualified — adapter quirk
  before_create  { self.id ||= SecureRandom.uuid }

  validates :title, presence: true
end
```

`Article.find(id)` works because AR generates a single-column `WHERE id = '…'`
that NodeDB does resolve, and the `select` in the default scope feeds the
projection.

### 3. Schema migrations work via the adapter

Rails normally tracks every applied migration's version in a
`schema_migrations` table; in **development** AR's `check_pending!` hook
runs on every request and raises `PendingMigrationError` if any
migration in `db/migrate/` isn't recorded. NodeDB doesn't accept
standard `CREATE TABLE`, so out of the box this hook 500s every page.

The adapter ships **NodeDB-aware** `SchemaMigration` and
`InternalMetadata` subclasses (PR #24) that use
`CREATE COLLECTION ... WITH (engine='document_strict')` plus raw
unqualified SQL. Effect:

- `config/environments/development.rb` keeps the Rails default
  `migration_error: :page_load` — no override needed.
- `bin/setup` (provided here) creates both tracking collections, runs
  every migration, and records the versions. Idempotent.
- `rails db:rollback` etc work because the DELETE path piggybacks on
  the BUG-008 workaround.

```bash
mise x -- bundle exec ruby bin/setup
# ==> Creating schema_migrations + ar_internal_metadata
# ==> Running 001_create_articles.rb
# ...
# Done. Applied versions: ["001", "002", "003", "004", "005", "006"]
```

After running `bin/setup`, every page in dev serves normally and
`schema_migrations` lives as a real NodeDB collection (`SHOW
COLLECTIONS` lists it). To inspect manually:

```ruby
ActiveRecord::Base.connection_pool.schema_migration.versions
# => ["001", "002", ..., "006"]

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

## Known follow-ups for the adapter

These belong in `activerecord-nodedb-adapter` rather than user code:

- **SELECT-* unwrap**: schemaless collections return `{result: <json>}`
  instead of flat columns; the adapter should detect and unwrap.
- **Strip table qualifier from SELECT projections** (or rewrite SQL in
  `exec_query`) so AR's default `"table"."col"` works without a model
  workaround.
- **Stub `schema_migrations` reads** so Rails' migration-error guard works
  with `migration_error: :page_load`.
- **Silence harmless `INSERT EDGE` pg-gem warnings** that print to stderr
  during graph writes.

## Test results

Adapter RSpec suite: **13 examples, 0 failures, 0 pending** (after BUG-001 was
fixed in NodeDB source — see `../bugs/001-insert-resources-exhausted-non-timeseries.md`).

CRUD walkthrough: all 7 REST verbs pass against a live NodeDB build.
