require "test_helper"

class StoredFilesControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  teardown do
    StoredFile.all.to_a.each(&:purge!)
  rescue StandardError
    nil
  end

  test "GET /stored_files returns 200" do
    get stored_files_path
    assert_response :success
  end

  test "upload, download, delete round-trip through the kv engine" do
    binary = (0..255).to_a.pack("C*") * 40 # 10 KB of every byte value

    post stored_files_path, params: {
      file: Rack::Test::UploadedFile.new(StringIO.new(binary), "application/octet-stream",
                                         original_filename: "bytes.bin")
    }
    assert_redirected_to stored_files_path

    file = StoredFile.find_by(filename: "bytes.bin")
    assert file, "metadata row missing"
    assert_equal binary.bytesize, file.byte_size.to_i

    get stored_file_path(file)
    assert_response :success
    assert_equal binary.b, response.body.b, "kv round-trip corrupted the payload"

    delete stored_file_path(file)
    assert_redirected_to stored_files_path
    assert_nil StoredFile.find_by(filename: "bytes.bin")
    assert_nil FileBlob.kv_get(file.id)
  end

  test "rejects uploads over the kv payload cap" do
    too_big = "x" * (StoredFile::MAX_BYTES + 1)

    post stored_files_path, params: {
      file: Rack::Test::UploadedFile.new(StringIO.new(too_big), "text/plain",
                                         original_filename: "big.txt")
    }
    assert_redirected_to stored_files_path
    follow_redirect!
    assert_match(/Too large/, flash[:alert].to_s)
    assert_nil StoredFile.find_by(filename: "big.txt")
  end
end
