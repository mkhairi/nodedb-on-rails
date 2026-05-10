class SocialNode < ApplicationRecord
  include NodeDB::Graph

  self.table_name  = "social_nodes"
  self.primary_key = "id"

  # NodeDB schemaless collections only expose `id` to schema introspection;
  # declare the user-facing columns so AR's attribute writers exist.
  attribute :id,   :string
  attribute :name, :string

  default_scope { select("id, name") }
end
