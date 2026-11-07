class KvSession < ApplicationRecord
  include NodeDB::KV

  self.table_name  = "kv_sessions"
  self.primary_key = :key
end
