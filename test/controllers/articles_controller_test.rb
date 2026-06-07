require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET / redirects/serves the articles index" do
    get root_path
    assert_response :success
    assert_match(/Articles/, response.body)
  end

  test "GET /articles returns 200 and renders the table" do
    get articles_path
    assert_response :success
    assert_match(/Articles/, response.body)
  end

  test "GET /articles/search renders the search form" do
    get search_articles_path
    assert_response :success
  end

  test "GET /articles/new shows the form" do
    get new_article_path
    assert_response :success
    assert_match(/title/i, response.body)
  end
end
