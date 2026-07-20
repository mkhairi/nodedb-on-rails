# NodeDB multi-tenancy demo. A tenant is a server-side isolation
# boundary: users are bound to a tenant at CREATE USER time, and every
# connection authenticated as that user sees only the tenant's own
# collections (the default tenant's `articles` etc. are invisible).
# There is no SET/USE TENANT — tenancy binds per user, per connection.
#
# This model is the registry row in the DEFAULT tenant (id = tenant
# name) plus the provisioning DDL, which runs over the app's normal
# superuser connection:
#
#   CREATE TENANT <name>
#   CREATE USER t_<name> PASSWORD '<generated>' TENANT <name>
#
# Tenant-scoped work goes through Tenant#session (a short-lived
# NodeDB::Connection authenticated as the tenant user) — see
# TenantSession.
class Tenant < ApplicationRecord
  self.table_name  = "tenant_registry"
  self.primary_key = "id"

  # Bare identifier only — tenant DDL takes unquoted names, so the
  # format guard is also the injection guard.
  NAME_RE = /\A[a-z][a-z0-9_]{2,29}\z/

  validates :id, presence: true, format: { with: NAME_RE,
    message: "must be 3-30 chars: lowercase letter first, then a-z 0-9 _" }

  alias_attribute :name, :id

  def self.provision!(name)
    tenant = new(id: name.to_s, username: "t_#{name}",
                 password: SecureRandom.alphanumeric(16),
                 created_at: Time.current.iso8601)
    raise ActiveRecord::RecordInvalid, tenant unless tenant.valid?

    # NodeDB accepts duplicate tenant names (creates a second tenant id
    # under the same name), so guard here. SHOW TENANT raises on an
    # unknown name — that is the good case.
    if exists?(id: tenant.id) || tenant_exists_server_side?(tenant.id)
      tenant.errors.add(:id, "already exists")
      raise ActiveRecord::RecordInvalid, tenant
    end

    connection.execute("CREATE TENANT #{tenant.id}")
    connection.execute(
      "CREATE USER #{tenant.username} PASSWORD #{connection.quote(tenant.password)} " \
      "TENANT #{tenant.id}"
    )
    # Built-in role; without it the tenant user cannot DROP even the
    # collections it created, and retired tenants would leave orphaned
    # collections behind (which fail the daemon's boot integrity check).
    connection.execute("GRANT tenant_admin TO #{tenant.username}")
    tenant.save!
    tenant
  end

  # Provision-only on purpose: there is no retire. DROP TENANT
  # deadlocks once the tenant's built-in admin has inherited ownership
  # of anything a dropped user owned — upstream BUG-051 in the
  # adapter's bug tracker (successor to the fixed BUG-035 boot brick).
  # Keeping the registry row also keeps the credentials, so a tenant
  # stays usable across app restarts.
  def self.find_or_provision!(name)
    find_by(id: name.to_s) || provision!(name)
  end

  def self.tenant_exists_server_side?(name)
    !connection.show_tenant(name).nil?
  rescue ActiveRecord::StatementInvalid
    false
  end

  # SHOW TENANTS counter row for this tenant (request totals etc.), or nil.
  def counters
    self.class.connection.show_tenant(id)
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def session
    TenantSession.new(self)
  end
end
