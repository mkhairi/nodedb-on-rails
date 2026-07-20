require "test_helper"

class EmbeddingsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /embeddings returns 200" do
    get embeddings_path
    assert_response :success
  end

  test "GET /embeddings/search returns 200 (vector index)" do
    get search_embeddings_path, params: { q: "rails" }
    assert_response :success
  end
end
