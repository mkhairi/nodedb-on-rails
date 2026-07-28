class ServerInfoController < ApplicationController
  INTERNAL_COLLECTIONS = %w[schema_migrations ar_internal_metadata].freeze

  # The adapter targets NodeDB 0.4.0+; older lines reject the DDL and
  # engine clauses it emits. Nothing enforces this at connect yet, so
  # the page reports it.
  MINIMUM_NODEDB_VERSION = Gem::Version.new("0.4.0")

  def index
    conn = ActiveRecord::Base.connection
    pool = ActiveRecord::Base.connection_pool

    cfg = pool.db_config.configuration_hash
    native = conn.respond_to?(:native_transport?) && conn.native_transport?
    transport = native ? "native" : "pg"
    raw_version = safe_show(conn, "server_version")
    @server = {
      version:           raw_version,
      nodedb_version:    nodedb_version(raw_version),
      pg_compat_version: pg_compat_version(raw_version),
      version_supported: version_supported?(nodedb_version(raw_version)),
      minimum_version:   MINIMUM_NODEDB_VERSION.to_s,
      application_name:  safe_show(conn, "application_name"),
      transport:         transport,
      transport_detail:  native ? "NodeDB binary (MessagePack), no libpq" : "PostgreSQL wire via libpq/pg",
      host:              cfg[:host] || pool.db_config.host,
      port:              cfg[:port] || (native ? 6433 : 6432),
      database:          cfg[:database] || pool.db_config.database,
      user:              cfg[:username] || cfg[:user],
      adapter_name:      conn.adapter_name,
      database_version:  conn.database_version,
      prepared:          conn.prepared_statements,
      ar_version:        ActiveRecord::VERSION::STRING,
      rails_version:     Rails.version,
      ruby_version:      RUBY_VERSION
    }

    @adapter_gem = {
      nodedb_ruby:       gem_version("nodedb-ruby"),
      ar_adapter:        gem_version("activerecord-nodedb-adapter"),
      pg:                gem_version("pg")
    }

    @migrations = {
      versions:          pool.schema_migration.versions,
      environment:       pool.internal_metadata[:environment],
      schema_sha1:       pool.internal_metadata[:schema_sha1]
    }

    @collections = conn.execute("SHOW COLLECTIONS").to_a.map do |row|
      name = row["name"]
      next if INTERNAL_COLLECTIONS.include?(name)
      # SHOW COLLECTIONS lists tenant-homed collections too, but the
      # superuser session can't DESCRIBE them — skip those rows.
      describe = begin
        conn.execute("DESCRIBE #{name}").to_a
      rescue ActiveRecord::StatementInvalid
        next
      end
      engine   = describe.find { |r| r["field"] == "__storage" }&.fetch("type") || "schemaless"
      cols     = describe.reject { |r| r["field"].to_s.start_with?("__") }
      count    = safe_count(conn, name)
      OpenStruct.new(
        name:        name,
        engine:      engine,
        owner:       row["owner"],
        created_at:  Time.at(row["created_at"].to_i),
        column_count: cols.size,
        columns:     cols.map { |c| "#{c["field"]}:#{c["type"]}" },
        row_count:   count
      )
    end.compact.sort_by(&:name)

    @internal = conn.execute("SHOW COLLECTIONS").to_a.select { |r| INTERNAL_COLLECTIONS.include?(r["name"]) }

    # NodeDB operational SHOW commands. Each returns Array<Hash>;
    # the helpers fail closed (`safe_show_array`) so a stricter NodeDB
    # build or a non-superuser session can't blank the whole page.
    # Real row sets on both transports since upstream fixed native
    # SHOW routing.
    @ops_stats   = safe_show_array(conn, :show_stats)
    @ops_metrics = safe_show_array(conn, :show_metrics)
    @ops_memory  = safe_show_array(conn, :show_memory)
    @ops_roles   = safe_show_array(conn, :show_roles)
    @ops_tenant  = safe_show_tenant(conn, 0)

    # Bare SHOW TENANTS / SHOW USERS need a superuser session and have no
    # adapter helper yet — raw execute, failing closed like the rest.
    @ops_tenants = safe_rows(conn, "SHOW TENANTS")
    @ops_users   = safe_rows(conn, "SHOW USERS")
    @ops_graph   = safe_show_array(conn, :graph_stats).map do |g|
      g.merge("labels" => parse_labels(g["labels"]))
    end

    @stats_by_name = @ops_stats.to_h { |r| [r["name"], r["value"]] }

    # What the adapter stands in for on this build, read live rather
    # than copied from docs.
    @compensations = compensations(conn)

    # A restart can leave the data directory replaying its metadata log
    # forever, after which every CREATE / DROP fails with "metadata
    # propose timed out" while reads and writes keep working. The probe
    # is DDL, so it runs only when asked for.
    @ddl_probe = params[:ddl_probe].present? ? run_ddl_probe(conn) : nil
  end

  private

  # SHOW server_version reports the PostgreSQL compatibility level with
  # the NodeDB version in parentheses: "15.0 (NodeDB 0.4.0)".
  NODEDB_VERSION_RE = /NodeDB\s+([\d.]+)/i
  PG_COMPAT_RE      = /\A([\d.]+)/

  def nodedb_version(raw)
    NODEDB_VERSION_RE.match(raw.to_s)&.[](1)
  end

  def pg_compat_version(raw)
    PG_COMPAT_RE.match(raw.to_s)&.[](1)
  end

  def version_supported?(version)
    return nil if version.blank?

    Gem::Version.new(version) >= MINIMUM_NODEDB_VERSION
  rescue ArgumentError
    nil
  end

  def compensations(conn)
    [
      { name:   "current_database()",
        detail: "answered from the connection config — the server has no such function",
        value:  safe_current_database(conn) },
      { name:   "advisory locks",
        detail: "pg_advisory_* is unimplemented; the migration mutex is a collection",
        value:  ActiveRecord::ConnectionAdapters::NodedbAdapter::ADVISORY_LOCKS_COLLECTION },
      { name:   "schema reflection",
        detail: "DESCRIBE instead of pg_attribute — catalog coverage is per-engine",
        value:  "DESCRIBE" },
      { name:   "prepared statements",
        detail: "NodeDB sends DataRow without RowDescription, so AR stays in simple-query mode",
        value:  conn.prepared_statements ? "enabled" : "disabled" }
    ]
  end

  def safe_current_database(conn)
    conn.current_database
  rescue StandardError
    nil
  end

  def run_ddl_probe(conn)
    name = "__ddl_probe_#{SecureRandom.hex(4)}"
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    conn.create_collection(name)
    conn.drop_collection(name, if_exists: true)
    { ok: true, elapsed_ms: elapsed_ms_since(started) }
  rescue StandardError => e
    conn.drop_collection(name, if_exists: true) rescue nil
    { ok: false, elapsed_ms: elapsed_ms_since(started), error: e.message.to_s.lines.first.to_s.strip }
  end

  def elapsed_ms_since(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end

  def safe_show(conn, key)
    conn.execute("SHOW #{key}").to_a.first&.values&.first
  rescue StandardError
    nil
  end

  def safe_count(conn, collection)
    conn.execute("SELECT id FROM #{collection}").to_a.size
  rescue StandardError
    nil
  end

  def gem_version(name)
    Gem.loaded_specs[name]&.version&.to_s
  end

  def safe_show_array(conn, method)
    return [] unless conn.respond_to?(method)

    conn.public_send(method)
  rescue StandardError
    []
  end

  # SHOW GRAPH STATS emits labels as a JSON array string,
  # e.g. [{"count":4,"label":"follows"}].
  def parse_labels(value)
    return value if value.is_a?(Array)

    JSON.parse(value.to_s)
  rescue JSON::ParserError
    []
  end

  def safe_rows(conn, sql)
    conn.execute(sql).to_a
  rescue StandardError
    []
  end

  def safe_show_tenant(conn, ref)
    return nil unless conn.respond_to?(:show_tenant)

    conn.show_tenant(ref)
  rescue StandardError
    nil
  end
end
