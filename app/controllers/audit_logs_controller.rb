# NodeDB v0.3.0 BITEMPORAL collection demo.
#
# EXPERIMENTAL. Reads run through raw SQL + a manual blob unwrap because
# NodeDB v0.3.0's bitemporal SELECT still returns each row in the
# `{data:{...}, id: <surrogate>}` shape over both transports (BUG-018
# territory). When upstream lands virtual-column projection on bitemporal
# collections, this controller can collapse to plain ActiveRecord queries.
class AuditLogsController < ApplicationController
  def index
    conn = ActiveRecord::Base.connection
    raw  = conn.execute("SELECT id, actor, action, target, context, recorded_at FROM audit_logs").to_a
    @logs = raw.map { |row| unwrap_bitemporal_row(row) }.compact.sort_by { |r| r[:recorded_at].to_s }.reverse
  end

  def create
    log = AuditLog.new(
      actor:       params[:actor].presence       || "anonymous",
      action:      params[:action_name].presence || "viewed",
      target:      params[:target].presence      || "/articles",
      context:     params[:context].presence     || "{}",
      recorded_at: Time.current.iso8601
    )

    if log.save
      redirect_to audit_logs_path, notice: "Audit entry #{log.id} recorded."
    else
      redirect_to audit_logs_path, alert: "Failed: #{log.errors.full_messages.to_sentence}"
    end
  end

  private

  # NodeDB v0.3.0 bitemporal SELECT returns `{ "data" => "<json>", "id" => "..."}`
  # where the inner `data` blob carries the actual document fields. Until
  # upstream projects virtual columns out, unwrap it here.
  def unwrap_bitemporal_row(row)
    if row.key?("data") && row["data"].is_a?(String) && row["data"].start_with?("{")
      payload = JSON.parse(row["data"])
      payload.transform_keys(&:to_sym).merge(_blob_id: row["id"])
    else
      row.transform_keys(&:to_sym)
    end
  rescue JSON::ParserError
    nil
  end
end
