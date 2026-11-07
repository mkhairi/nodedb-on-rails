class Article < ApplicationRecord
  self.table_name  = "articles"
  self.primary_key = "id"

  # AR's default projection and hash-where conditions work: the adapter
  # strips the table qualifier that upstream mishandles in IN, BETWEEN
  # and LIKE.
  validates :title, presence: true

  before_create { self.id ||= SecureRandom.uuid }
end
