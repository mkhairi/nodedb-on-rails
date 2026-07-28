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
  # Three "topic" axes: [systems, ml, product]. Titles cluster so a
  # query vector lands on a coherent neighbourhood rather than an
  # arbitrary row — searching [0.9, 0.1, 0.1] should return the
  # systems documents, not a scatter.
  SAMPLES = [
    { id: "seed_e01", title: "Sharding strategies for multi-model stores", vec: [0.92, 0.08, 0.15] },
    { id: "seed_e02", title: "Write-ahead logging and crash recovery",     vec: [0.88, 0.05, 0.10] },
    { id: "seed_e03", title: "Connection pooling under burst load",        vec: [0.85, 0.12, 0.22] },
    { id: "seed_e04", title: "Approximate nearest neighbour indexes",      vec: [0.55, 0.75, 0.18] },
    { id: "seed_e05", title: "Embedding models for retrieval",             vec: [0.20, 0.94, 0.16] },
    { id: "seed_e06", title: "Fine-tuning vs prompt engineering",          vec: [0.10, 0.90, 0.30] },
    { id: "seed_e07", title: "Evaluating RAG pipelines",                   vec: [0.25, 0.82, 0.40] },
    { id: "seed_e08", title: "Pricing tiers that survive contact",         vec: [0.12, 0.20, 0.91] },
    { id: "seed_e09", title: "Onboarding funnels and activation",          vec: [0.08, 0.25, 0.88] },
    { id: "seed_e10", title: "Support triage without a support team",      vec: [0.30, 0.15, 0.80] }
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
