require "test_helper"

# Posts run on a document_strict collection + CREATE FULLTEXT INDEX.
class PostsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /posts returns 200" do
    get posts_path
    assert_response :success
  end

  test "GET /posts/search with a query returns 200" do
    get search_posts_path, params: { q: "rails" }
    assert_response :success
  end

  test "GET /posts/search without a query renders empty-state" do
    get search_posts_path
    assert_response :success
  end
end
