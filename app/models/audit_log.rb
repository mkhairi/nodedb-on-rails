# NodeDB v0.3.0 BITEMPORAL collection demo.
#
# EXPERIMENTAL — see `db/migrate/008_create_audit_logs.rb` for the upstream
# caveat (BUG-018 SELECT shape on bitemporal collections). Writes work
# straight through ActiveRecord; reads bypass the model and go through
# the controller's manual blob-unwrap.
class AuditLog < ApplicationRecord
  self.table_name  = "audit_logs"
  self.primary_key = "id"

  default_scope { select("id, actor, action, target, context, recorded_at") }

  before_create { self.id ||= SecureRandom.uuid }
end
