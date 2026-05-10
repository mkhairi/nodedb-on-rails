source "https://rubygems.org"

gem "rails", "~> 8.1"
gem "pg",    "~> 1.5"

gem "propshaft"
gem "puma", ">= 6.0"

# NodeDB gems. Both are alpha. A local Gemfile.local (gitignored) can
# override these with `path:` sources for monorepo development.
local_override = File.expand_path("Gemfile.local", __dir__)
if File.exist?(local_override)
  eval_gemfile(local_override)
else
  gem "nodedb-ruby",                 github: "mkhairi/nodedb-ruby",                 branch: "main"
  gem "activerecord-nodedb-adapter", github: "mkhairi/activerecord-nodedb-adapter", branch: "main"
end

group :development do
  gem "web-console"
end

group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end
