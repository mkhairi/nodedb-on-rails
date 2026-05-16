class Embedding < ApplicationRecord
  include NodeDB::Vector

  self.table_name         = "embeddings"
  self.primary_key        = "id"
  self.inheritance_column = :_type_disabled

  vector_column :embedding, dim: 3

  # The `embeddings` collection is schemaless: NodeDB vector SEARCH
  # returns surrogate ids + distances and does not project document
  # fields, and a plain scan of a schemaless collection is unreliable.
  # So the demo's catalog is this fixed seed set (also used by
  # db/seeds.rb). Surrogate ids returned by search map to insertion
  # order, i.e. this array's index.
  SAMPLES = [
    { id: "seed_e1", title: "Intro to AI",     vec: [0.10, 0.20, 0.30] },
    { id: "seed_e2", title: "Deep Learning",   vec: [0.40, 0.50, 0.60] },
    { id: "seed_e3", title: "Graph Databases", vec: [0.90, 0.10, 0.10] },
    { id: "seed_e4", title: "Vector Search",   vec: [0.15, 0.25, 0.35] }
  ].freeze

  # Insert one row via a raw ARRAY[...] literal (the form NodeDB's
  # schemaless collection + vector index accept).
  def self.insert_vector(id:, title:, vec:)
    conn = connection
    conn.execute(
      "INSERT INTO #{table_name} (id, title, embedding) VALUES (" \
      "#{conn.quote(id)}, #{conn.quote(title)}, ARRAY[#{vec.map(&:to_f).join(', ')}])"
    )
  end
end
