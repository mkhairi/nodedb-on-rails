# NodeDB BITEMPORAL collection demo.
#
# Reads and writes are plain ActiveRecord on current upstream —
# transactional INSERT/DELETE persist on bitemporal collections, so
# create!/update!/destroy version normally. Time-travel reads come
# from the NodeDB::Bitemporal concern (versions / history / as_of).
class AuditLog < ApplicationRecord
  include NodeDB::Bitemporal

  self.table_name  = "audit_logs"
  self.primary_key = "id"

  before_create { self.id ||= SecureRandom.uuid }

  validates :actor, :action, :target, :recorded_at, presence: true

  # Kept as the app-facing write entry point (callers predate the
  # upstream fix that made plain create! safe here).
  def self.record!(attrs)
    create!(attrs)
  end
end
