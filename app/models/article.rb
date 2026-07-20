class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  # AR's default qualified projection and hash-where conditions work —
  # no select-list scope needed on document_strict. (Qualified refs
  # matched zero rows upstream for most of the alpha — BUG-025, since
  # fixed; the adapter's dequalifier workaround is removed.)
  validates :title, presence: true

  before_create { self.id ||= SecureRandom.uuid }
end
