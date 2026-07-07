# Metadata row for an uploaded file; the body lives in FileBlob (kv).
class StoredFile < ApplicationRecord
  # ponytail: single-value kv payload, so uploads cap below NodeDB's
  # ~2 MB WAL write limit; chunked kv values if bigger files matter.
  MAX_BYTES = 1_500_000

  self.table_name  = "stored_files"
  self.primary_key = "id"

  default_scope { select("id, filename, content_type, byte_size, uploaded_at") }

  before_create { self.id ||= SecureRandom.uuid }

  validates :filename, presence: true
  validates :byte_size, numericality: { less_than_or_equal_to: MAX_BYTES }

  def self.store!(upload)
    binary = upload.read
    record = create!(
      filename:     upload.original_filename.to_s,
      content_type: upload.content_type.presence || "application/octet-stream",
      byte_size:    binary.bytesize,
      uploaded_at:  Time.current.utc.iso8601
    )
    FileBlob.write(record.id, binary)
    record
  end

  def body
    FileBlob.read(id)
  end

  def purge!
    FileBlob.kv_delete(id)
    destroy!
  end
end
