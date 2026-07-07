class StoredFilesController < ApplicationController
  def index
    @files = StoredFile.order(uploaded_at: :desc).to_a
  end

  def create
    upload = params[:file]
    if upload.blank?
      redirect_to(stored_files_path, alert: "Pick a file first.") and return
    end
    if upload.size > StoredFile::MAX_BYTES
      redirect_to(stored_files_path,
        alert: "Too large (#{helpers.number_to_human_size(upload.size)}). " \
               "Max #{helpers.number_to_human_size(StoredFile::MAX_BYTES)} — " \
               "single kv value, NodeDB WAL caps writes at ~2 MB.") and return
    end

    file = StoredFile.store!(upload)
    redirect_to stored_files_path, notice: "Stored #{file.filename}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to stored_files_path, alert: e.message
  end

  def show
    file = StoredFile.find(params[:id])
    body = file.body
    if body.nil?
      redirect_to(stored_files_path, alert: "Blob missing for #{file.filename}.") and return
    end
    send_data body, filename: file.filename, type: file.content_type,
                    disposition: params[:inline] ? "inline" : "attachment"
  end

  def destroy
    StoredFile.find(params[:id]).purge!
    redirect_to stored_files_path, notice: "Deleted.", status: :see_other
  end
end
