class KvSessionsController < ApplicationController
  def index
    @entries = KvSession.unscoped.from(KvSession.table_name).select("key, value").order(:key).to_a
    @lookup_key   = params[:k].to_s
    @lookup_value = KvSession.kv_get(@lookup_key) if @lookup_key.present?
  end

  def create
    key   = params[:key].to_s.strip
    value = params[:value].to_s
    if key.blank?
      redirect_to(kv_sessions_path, alert: "Key required.") and return
    end
    KvSession.kv_set(key, value)
    redirect_to kv_sessions_path, notice: "Saved #{key}."
  end

  def destroy
    KvSession.kv_delete(params[:key])
    redirect_to kv_sessions_path, notice: "Deleted #{params[:key]}.", status: :see_other
  end

  def inspect_key
    @key   = params[:k].to_s
    @value = KvSession.kv_get(@key)
  end
end
