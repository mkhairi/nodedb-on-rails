require "test_helper"

class EmbeddingsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /embeddings returns 200" do
    get embeddings_path
    assert_response :success
  end

  test "GET /embeddings/search returns 200 (vector index)" do
    # Native transport fails with `TypeError: no implicit conversion
    # of nil into String` for vector.search (BUG-018).
    skip_native "vector.search returns nil distance — adapter has no unwrap (BUG-018, issue #45)"

    get search_embeddings_path, params: { q: "rails" }
    assert_response :success
  end
end
