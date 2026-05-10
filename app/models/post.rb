class Post < ApplicationRecord
  include NodeDB::FullTextSearch

  self.table_name  = "posts"
  self.primary_key = "id"

  default_scope { select("id, title, body") }
  fts_column :body, language: "english"

  before_create { self.id ||= SecureRandom.uuid }
end
