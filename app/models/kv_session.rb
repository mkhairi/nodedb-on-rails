class KvSession < ApplicationRecord
  include NodeDB::KV

  self.table_name  = "kv_sessions"
  self.primary_key = :key

  # NodeDB returns SELECT * as a JSON wrapper instead of flat columns;
  # explicit unqualified projection avoids that and AR-quoting both.
  default_scope { select("key, value") }
end
