class SocialNodesController < ApplicationController
  def index
    @nodes = SocialNode.all.to_a
    @from  = params[:from].presence
    @depth = (params[:depth].presence || 2).to_i
    @reachable = SocialNode.graph_traverse(from: @from, depth: @depth) if @from
  end

  def new
    @node = SocialNode.new
  end

  def create
    @node = SocialNode.new(node_params)
    if @node.id.blank?
      @node.errors.add(:id, "is required (used as graph node identifier)")
      return render :new, status: :unprocessable_entity
    end
    if @node.save
      redirect_to social_nodes_path, notice: "Node #{@node.id} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edge
    SocialNode.graph_insert_edge(
      from: params[:from].to_s,
      to:   params[:to].to_s,
      type: (params[:edge_type].presence || "follows")
    )
    redirect_to social_nodes_path(from: params[:from], depth: 2),
                notice: "Edge #{params[:from]} -[#{params[:edge_type]}]-> #{params[:to]} created."
  end

  def traverse
    @from  = params[:from].to_s
    @depth = (params[:depth].presence || 2).to_i
    @nodes = SocialNode.graph_traverse(from: @from, depth: @depth)
  end

  def graph
    @nodes = SocialNode.all.to_a
    pr = SocialNode.graph_algo(:pagerank, damping: 0.85, iterations: 20, tolerance: 1e-4)
    @pagerank = pr.each_with_object(Hash.new(0.0)) do |r, h|
      key = r["node_id"] || r["id"] || r["node"]
      val = (r["rank"] || r["score"] || r["pagerank"]).to_f
      h[key] = val if val > h[key]
    end
  rescue => e
    @error = e.message
    @nodes ||= []
    @pagerank = {}
  end

  def destroy
    SocialNode.find(params[:id]).destroy
    redirect_to social_nodes_path, notice: "Node deleted.", status: :see_other
  end

  private

  def node_params
    params.expect(social_node: %i[id name])
  end
end
