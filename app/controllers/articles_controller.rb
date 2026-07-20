class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    # Ruby-side filter: after a daemon restart the articles shard can
    # surface ghost tuples that scan as all-NULL rows and match no SQL
    # predicate (not even IS NULL — that matches real rows instead), so
    # they can't be excluded or deleted server-side (upstream, BUG-052).
    @articles = Article.all.to_a.select { |a| a.id.present? }
  end

  def show; end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Article updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy
    redirect_to articles_path, notice: "Article deleted.", status: :see_other
  end

  def search
    @query = params[:q].to_s
    @articles = if @query.present?
      Article.where("title LIKE ?", "%#{@query}%").to_a
    else
      []
    end
    render :index
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def article_params
    params.expect(article: %i[title body])
  end
end
