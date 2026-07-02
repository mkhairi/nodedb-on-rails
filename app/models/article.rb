class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  # The adapter dequalifies single-table statements (BUG-025
  # workaround), so AR's default qualified projection and hash-where
  # conditions work — no select-list scope needed on document_strict.
  validates :title, presence: true

  before_create { self.id ||= SecureRandom.uuid }
end
