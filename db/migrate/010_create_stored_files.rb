# File-upload demo: binary payloads on the KV engine.
#
# Two collections: `file_blobs` (kv) holds the Base64-encoded file
# body under the file's id; `stored_files` (document_strict) holds
# the metadata row. Payloads cap at ~1.5 MB raw — NodeDB's WAL
# rejects writes past ~2 MB per statement.
class CreateStoredFiles < ActiveRecord::Migration[8.0]
  def up
    create_kv :file_blobs do |t|
      t.column :key,   "TEXT PRIMARY KEY"
      t.column :value, :text
    end

    create_document_strict :stored_files do |t|
      t.column :id,          "TEXT PRIMARY KEY"
      t.column :filename,    :text
      t.column :content_type, :text
      t.column :byte_size,   :integer
      t.column :uploaded_at, :text
    end
  end

  def down
    drop_collection :stored_files, if_exists: true
    drop_collection :file_blobs,   if_exists: true
  end
end
