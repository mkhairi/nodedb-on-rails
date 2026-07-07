class ServerInfoController < ApplicationController
  INTERNAL_COLLECTIONS = %w[schema_migrations ar_internal_metadata].freeze

  def index
    conn = ActiveRecord::Base.connection
    pool = ActiveRecord::Base.connection_pool

    cfg = pool.db_config.configuration_hash
    native = conn.respond_to?(:native_transport?) && conn.native_transport?
    transport = native ? "native" : "pg"
    @server = {
      version:           safe_show(conn, "server_version"),
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
        column_count: cols.size - 1,  # drop the synthetic baseline id
        columns:     cols.map { |c| "#{c["field"]}:#{c["type"]}" },
        row_count:   count
      )
    end.compact.sort_by(&:name)

    @internal = conn.execute("SHOW COLLECTIONS").to_a.select { |r| INTERNAL_COLLECTIONS.include?(r["name"]) }

    # NodeDB operational SHOW commands. Each returns Array<Hash>;
    # the helpers fail closed (`safe_show_array`) so a stricter NodeDB
    # build or a non-superuser session can't blank the whole page.
    # Real row sets on both transports since upstream fixed native
    # SHOW routing (BUG-022).
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
  end

  private

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
