class CreateEmbeddings < ActiveRecord::Migration[8.0]
  # Vector engine demo. A schemaless document collection + a cosine
  # vector index on `embedding` (dim 3, hand-typeable). This mirrors the
  # proven feature_smoke recipe: NodeDB `SEARCH … USING VECTOR()` returns
  # internal surrogate ids + distances and does NOT project document
  # fields, so the UI drives its catalog from a fixed seed list rather
  # than scanning the (schemaless) collection.
  def up
    create_collection :embeddings
    create_vector_index "idx_embeddings_emb",
                        on: :embeddings, column: :embedding,
                        metric: :cosine, dim: 3
  end

  def down
    drop_vector_index "idx_embeddings_emb" rescue nil
    drop_collection :embeddings, if_exists: true
  end
end
