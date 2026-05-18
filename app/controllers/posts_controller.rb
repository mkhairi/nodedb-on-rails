class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy]

  def index
    @query = params[:q].to_s
    @hits  = []
    @posts = Post.all.to_a

    return if @query.blank?

    fts = Post.fts_search(@query, limit: 20)
    @hits = fts.filter_map do |row|
      post = Post.where("id = ?", row["id"]).first
      next unless post
      { id: row["id"], post: post }
    end
  end

  def show; end
  def new;  @post = Post.new;  end
  def edit; end

  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "Post deleted.", status: :see_other
  end

  def search
    index
    render :index
  end

  private

  def set_post
    @post = Post.where("id = ?", params[:id]).first or
      raise ActiveRecord::RecordNotFound
  end

  def post_params
    params.expect(post: %i[title body])
  end
end
