# nodedb-on-rails — project rules

Workspace-wide rules (branch/PR workflow, upstream-bug lifecycle,
versioning, "what to never do") live in the monorepo root:
`../CLAUDE.md`. **Read that first.** Anything below adds or overrides
for this app only.

## Project

End-to-end Rails 8 demo for `activerecord-nodedb-adapter` and the
NodeDB ecosystem. Exercises every NodeDB engine through a real
controller → view → ActiveRecord stack (pgwire by default; switch with
`NODEDB_TRANSPORT=native`): documents (Article, Post), graph
(SocialNode), spatial-via-document_strict (Location), KV (KvSession),
timeseries (Metric), full-text search, vector (Embedding), and a
bitemporal audit log (AuditLog).

Status: **alpha demo** (`0.1.0.alpha.1`). Disposable data only.

## Setup + tests

```bash
bundle install                                          # gems via github:
bundle exec ruby bin/setup                              # bootstrap migrations + dump db/schema.rb
bundle exec ruby bin/rails runner db/seeds.rb           # seed across every engine
bundle exec ruby bin/rails runner scripts/feature_smoke.rb   # 33-check engine smoke
bundle exec rails server -p 3737 -b 127.0.0.1           # browse http://127.0.0.1:3737/
```

Full test pass (run before any PR merges — pgwire AND native must be
green):

```bash
bundle exec rake test:both_transports    # minitest over pg + native
NODEDB_TRANSPORT=native bundle exec ruby bin/rails runner scripts/feature_smoke.rb
```

Note: dev and test environments share the default `nodedb` database
by convention (CREATE DATABASE'd databases were unusable for most of
the alpha — BUG-032 in the adapter's issue tracker, since fixed
upstream).

Drop a `Gemfile.local` (gitignored) for monorepo dev against local gem
checkouts; the main `Gemfile` evaluates it when present.

## License

BSD 2-Clause. See `LICENSE.md`.
