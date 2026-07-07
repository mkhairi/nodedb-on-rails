# KV-engine store for uploaded file bodies. Values are Base64 so the
# binary payload survives the text-only pgwire surface.
class FileBlob < ApplicationRecord
  include NodeDB::KV

  self.table_name  = "file_blobs"
  self.primary_key = :key

  default_scope { select("key, value") }

  def self.write(id, binary)
    kv_set(id, Base64.strict_encode64(binary))
  end

  def self.read(id)
    encoded = kv_get(id)
    encoded && Base64.decode64(encoded)
  end
end
