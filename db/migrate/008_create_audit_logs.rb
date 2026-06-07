# NodeDB v0.3.0 BITEMPORAL collection demo.
#
# EXPERIMENTAL — the BITEMPORAL modifier is accepted by the parser and the
# collection is persisted, but reads against bitemporal collections still
# emit the raw `{data,id}` blob shape over both pgwire and native (BUG-018
# territory). The AuditLog model and view unwrap the blob themselves until
# upstream lands virtual-column projection on bitemporal collections.
class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def up
    create_collection :audit_logs, engine: :document_strict, bitemporal: true do |t|
      t.column :id,         "TEXT PRIMARY KEY"
      t.column :actor,      :text
      t.column :action,     :text
      t.column :target,     :text
      t.column :context,    :text
      t.column :recorded_at, :text
    end
  end

  def down
    drop_collection :audit_logs, if_exists: true
  end
end
