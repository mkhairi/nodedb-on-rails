# NodeDB multi-tenancy demo: provision tenants + tenant-bound users
# over the app's superuser connection, then work inside a tenant's
# isolation boundary through a per-request tenant session (see
# TenantSession for the approach notes).
class TenantsController < ApplicationController
  def index
    @tenants  = Tenant.all.sort_by(&:id)
    @counters = safe_counters
  end

  def show
    @tenant = Tenant.find(params[:id])
    session = @tenant.session
    @collections     = session.collections
    @notes           = session.notes
    @isolation_error = session.isolation_error
    @counters        = @tenant.counters
  rescue ActiveRecord::RecordNotFound
    redirect_to tenants_path, alert: "Unknown tenant."
  end

  def create
    tenant = Tenant.provision!(params[:name].to_s.strip.downcase)
    redirect_to tenant_path(tenant), notice: "Tenant '#{tenant.id}' provisioned."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to tenants_path, alert: "Failed: #{e.record.errors.full_messages.to_sentence}"
  end

  def add_note
    tenant = Tenant.find(params[:id])
    tenant.session.add_note!(params[:body].presence || "hello from #{tenant.id}")
    redirect_to tenant_path(tenant), notice: "Note written inside tenant '#{tenant.id}'."
  end

  private

  # SHOW TENANTS rows keyed by name; fails closed on stricter builds.
  def safe_counters
    ActiveRecord::Base.connection.execute("SHOW TENANTS").to_a
                      .index_by { |r| r["name"] }
  rescue StandardError
    {}
  end
end
