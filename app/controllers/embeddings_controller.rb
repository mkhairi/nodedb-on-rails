class EmbeddingsController < ApplicationController
  def index
    @catalog = Embedding::SAMPLES
    @results = []
  end

  def search
    @catalog = Embedding::SAMPLES
    @vector  = parse_vec(params[:q])
    @results = @vector ? annotate(Embedding.search_vector(:embedding, @vector, limit: 5)) : []
    render :index
  rescue => e
    @error   = e.message
    @catalog = Embedding::SAMPLES
    @results = []
    render :index
  end

  def create
    vec = parse_vec(params[:embedding])
    unless vec
      return redirect_to(embeddings_path, alert: "Embedding needs 3 comma-separated numbers, e.g. 0.1, 0.2, 0.3")
    end

    Embedding.insert_vector(
      id:    "user_#{SecureRandom.hex(4)}",
      title: params[:title].presence || "untitled",
      vec:   vec
    )
    redirect_to embeddings_path, notice: "Embedding added (searchable; not in the seed catalog)."
  rescue => e
    redirect_to embeddings_path, alert: "Insert failed: #{e.message}"
  end

  private

  # NodeDB vector search returns {surrogate, distance}; surrogate is the
  # insertion-order index, so map it back to the seed catalog for a
  # human-readable title where possible.
  def annotate(results)
    results.map do |r|
      sample = Embedding::SAMPLES[r["surrogate"].to_i]
      r.merge("title" => sample&.dig(:title))
    end
  end

  def parse_vec(raw)
    parts = raw.to_s.split(",").map(&:strip)
    return nil unless parts.size == 3 && parts.all? { |p| p.match?(/\A-?\d+(\.\d+)?\z/) }

    parts.map(&:to_f)
  end
end
