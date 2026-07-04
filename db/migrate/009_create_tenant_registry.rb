# Registry of demo tenants provisioned from the /tenants page. Lives in
# the DEFAULT tenant; the id column carries the NodeDB tenant name.
# Stores the tenant-bound user's password in plaintext — demo-only
# convenience so the playground can reconnect (this app is
# disposable-data alpha by policy).
class CreateTenantRegistry < ActiveRecord::Migration[8.0]
  def up
    create_collection :tenant_registry, engine: :document_strict, id: false do |t|
      t.column :id, "TEXT PRIMARY KEY" # tenant name
      t.text :username
      t.text :password
      t.text :created_at
    end
  end

  def down
    drop_collection :tenant_registry, if_exists: true
  end
end
