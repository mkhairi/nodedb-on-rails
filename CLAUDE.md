# nodedb-on-rails — project rules

Workspace-wide rules (branch/PR workflow, upstream-bug lifecycle,
versioning, "what to never do") live in the monorepo root:
`../CLAUDE.md`. **Read that first.** Anything below adds or overrides
for this app only.

## Project

End-to-end Rails 8 demo for `activerecord-nodedb-adapter` and the
NodeDB ecosystem. Exercises every NodeDB engine through a real
controller → view → ActiveRecord → pgwire stack: documents (Article,
Post), graph (SocialNode), spatial-via-document_strict (Location),
KV (KvSession), timeseries (Metric), full-text search.

Status: **alpha demo** (`0.1.0.alpha.1`). Disposable data only.

## Setup + tests

```bash
bundle install                                          # gems via github:
bundle exec ruby bin/setup                              # bootstrap migrations + dump db/schema.rb
bundle exec ruby bin/rails runner db/seeds.rb           # seed across every engine
bundle exec ruby bin/rails runner scripts/feature_smoke.rb   # 21/21 engine smoke
bundle exec rails server -p 3737 -b 127.0.0.1           # browse http://127.0.0.1:3737/
```

Drop a `Gemfile.local` (gitignored) for monorepo dev against local gem
checkouts; the main `Gemfile` evaluates it when present.

## License

BSD 2-Clause. See `LICENSE.md`.
