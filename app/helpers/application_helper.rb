module ApplicationHelper
  ENGINE_COLOR = {
    "document_strict" => "azure",
    "timeseries"      => "lime",
    "kv"              => "yellow",
    "spatial"         => "green",
    "columnar"        => "purple",
    "graph"           => "pink",
    "fts"             => "orange",
    "vector"          => "indigo",
    "schemaless"      => "secondary"
  }.freeze

  def engine_color(engine)
    ENGINE_COLOR.fetch(engine.to_s, "secondary")
  end
end
