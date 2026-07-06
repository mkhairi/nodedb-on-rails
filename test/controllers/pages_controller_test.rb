require "test_helper"

# Intro + docs are static: they must render with or without a live
# daemon (no skip_if_daemon_down!).
class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders the intro with engine cards" do
    get root_path
    assert_response :success
    assert_match(/NodeDB on Rails/, response.body)
    # one card per engine demo
    %w[Articles Timeseries Tenants].each { |label| assert_match(label, response.body) }
    assert_match(/disposable data only/i, response.body)

    # Layout: Docs pinned in the sidebar footer, runtime versions in
    # the page footer.
    assert_match(/navbar-nav mt-auto/, response.body)
    assert_match(%r{href="#{docs_path}"}, response.body)
    assert_match(/Rails #{Regexp.escape(Rails.version)}/, response.body)
    assert_match(/Ruby #{Regexp.escape(RUBY_VERSION)}/, response.body)
  end

  test "GET /docs renders every section anchor" do
    get docs_path
    assert_response :success
    %w[setup transports documents fts spatial graph timeseries vector kv
       bitemporal tenants adapter operating-notes].each do |anchor|
      assert_match(/id="#{anchor}"/, response.body)
    end
  end
end
