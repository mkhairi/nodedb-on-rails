# NodeDB BITEMPORAL collection demo.
#
# Reads project real columns on current upstream (plain SELECT,
# count(*), AS OF SYSTEM TIME). AuditLog.record! writes autocommit —
# historically required (transactional INSERTs were lost on bitemporal
# collections, upstream BUG-024, since fixed) and kept because it
# works on every build.
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
