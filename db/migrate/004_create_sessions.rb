class CreateSessions < ActiveRecord::Migration[8.0]
  def up
    create_kv :kv_sessions do |t|
      t.column :key,   "TEXT PRIMARY KEY"
      t.column :value, :text
    end
  end

  def down
    drop_collection :kv_sessions, if_exists: true
  end
end
