# A short-lived connection authenticated as a tenant-bound user.
#
# Deliberately NOT ActiveRecord: tenancy binds at the connection level,
# so the playground opens a fresh NodeDB::Connection (pgwire) per
# request, runs its statements inside the tenant's isolation boundary,
# and closes. Rows come back as Array<Hash>. A real multi-tenant app
# would keep a connection pool per tenant (Rails `connects_to`) — this
# demo keeps the mechanics visible instead.
class TenantSession
  NOTES_DDL = "CREATE COLLECTION tenant_notes " \
              "(id TEXT PRIMARY KEY, body TEXT, created_at TEXT) " \
              "WITH (engine='document_strict')".freeze

  def initialize(tenant)
    @tenant = tenant
  end

  def collections
    with_conn { |c| c.exec("SHOW COLLECTIONS").to_a }
  end

  def notes
    with_conn do |c|
      ensure_notes(c)
      c.exec("SELECT id, body, created_at FROM tenant_notes").to_a
        .sort_by { |r| r["created_at"].to_s }
    end
  end

  def add_note!(body)
    with_conn do |c|
      ensure_notes(c)
      c.exec_params(
        "INSERT INTO tenant_notes (id, body, created_at) VALUES ($1, $2, $3)",
        [SecureRandom.uuid, body.to_s, Time.current.iso8601]
      )
    end
  end

  # Retirement hygiene: DROP TENANT leaves the tenant's collections
  # behind as daemon-wide orphans, so drop them from inside first.
  def drop_all_collections!
    with_conn do |c|
      c.exec("SHOW COLLECTIONS").to_a.each do |row|
        c.exec("DROP COLLECTION IF EXISTS #{row['name']}")
      end
    end
  end

  # Isolation proof: the default tenant's collections must be invisible
  # from this session. Returns the server error message (expected) or
  # nil if the query unexpectedly succeeds.
  def isolation_error(collection = "articles")
    with_conn do |c|
      c.exec("SELECT id FROM #{collection} LIMIT 1")
      nil
    end
  rescue PG::Error => e
    e.message.lines.first&.strip
  end

  private

  def ensure_notes(conn)
    return if conn.exec("SHOW COLLECTIONS").to_a.any? { |r| r["name"] == "tenant_notes" }

    conn.exec(NOTES_DDL)
  end

  def with_conn
    conn = connect_with_retry
    yield conn
  ensure
    conn&.close
  end

  # NodeDB transiently rejects correct credentials under connection
  # churn / right after CREATE USER (adapter bug tracker: BUG-034);
  # retry briefly before giving up.
  def connect_with_retry(attempts: 4)
    cfg = ActiveRecord::Base.connection_pool.db_config.configuration_hash
    NodeDB::Connection.connect(
      host:     cfg[:host] || "localhost",
      port:     6432, # tenant playground stays on pgwire
      dbname:   cfg[:database],
      user:     @tenant.username,
      password: @tenant.password
    )
  rescue PG::ConnectionBad => e
    raise unless e.message.match?(/authentication failed/i) && (attempts -= 1).positive?

    sleep 0.5
    retry
  end
end
