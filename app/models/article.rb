class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  # NodeDB's SQL parser does not resolve qualified column refs
  # ("articles".id, articles.id) — it returns nil for those columns.
  # Use a raw unqualified column list to get a usable result row.
  default_scope { select("id, title, body") }

  validates :title, presence: true

  before_create { self.id ||= SecureRandom.uuid }
end
