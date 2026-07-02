# NodeDB BITEMPORAL collection demo.
#
# Reads are plain ActiveRecord on current upstream — the bitemporal
# read path projects real columns for plain SELECT, count(*), and
# AS OF SYSTEM TIME.
#
# Writes must NOT go through AR's create!/save: NodeDB loses INSERTs
# committed inside explicit transactions on bitemporal collections
# (upstream BUG-024), and AR wraps every save in one. `AuditLog.record!`
# validates through the model, then issues a raw autocommit INSERT,
# which persists correctly.
class AuditLog < ApplicationRecord
  self.table_name  = "audit_logs"
  self.primary_key = "id"

  validates :actor, :action, :target, :recorded_at, presence: true

  # Validate via the model, write via raw autocommit SQL (no txn).
  def self.record!(attrs)
    log = new(attrs)
    log.id ||= SecureRandom.uuid
    raise ActiveRecord::RecordInvalid, log unless log.valid?

    conn = connection
    cols = %w[id actor action target context recorded_at]
    values = cols.map { |c| conn.quote(log.public_send(c)) }.join(", ")
    conn.execute("INSERT INTO #{table_name} (#{cols.join(', ')}) VALUES (#{values})")
    log
  end

  # Every committed version of every row, oldest first, including the
  # `_ts_system` commit timestamp (ms). `AS OF SYSTEM TIME NULL` is
  # NodeDB's audit-log scan; it doesn't compose with AR relations, so
  # rows come back as hashes.
  def self.versions
    connection
      .select_all("SELECT * FROM #{table_name} AS OF SYSTEM TIME NULL")
      .to_a
      .sort_by { |row| row["_ts_system"].to_i }
  end
end
