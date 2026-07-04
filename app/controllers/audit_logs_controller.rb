# NodeDB BITEMPORAL collection demo. Reads and writes are plain
# ActiveRecord on current upstream; time-travel reads come from the
# NodeDB::Bitemporal concern (versions / history / as_of).
class AuditLogsController < ApplicationController
  def index
    @logs     = AuditLog.all.sort_by { |l| l.recorded_at.to_s }.reverse
    @versions = AuditLog.versions.reverse
  end

  def create
    AuditLog.record!(
      actor:       params[:actor].presence       || "anonymous",
      action:      params[:action_name].presence || "viewed",
      target:      params[:target].presence      || "/articles",
      context:     params[:context].presence     || "{}",
      recorded_at: Time.current.iso8601
    )
    redirect_to audit_logs_path, notice: "Audit entry recorded."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to audit_logs_path, alert: "Failed: #{e.record.errors.full_messages.to_sentence}"
  end
end
