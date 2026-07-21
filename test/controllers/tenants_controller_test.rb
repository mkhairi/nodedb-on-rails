require "test_helper"

# Multi-tenancy demo: provisioning DDL over the superuser connection,
# tenant-scoped work through a per-request tenant session. A fixed
# tenant is reused across runs — provision-only, no retire (tenants
# become undroppable once their built-in admin inherits ownership,
# BUG-051).
class TenantsControllerTest < ActionDispatch::IntegrationTest
  NAME = "test_tenant".freeze

  setup { skip_if_daemon_down! }

  test "GET /tenants renders" do
    get tenants_path
    assert_response :success
    assert_match(/MULTI-TENANCY/, response.body)
  end

  test "provision (or reuse) and isolated playground" do
    post tenants_path, params: { name: NAME }
    assert_response :redirect
    tenant = Tenant.find_by(id: NAME)
    assert tenant, "tenant should exist after create"

    get tenant_path(NAME)
    assert_response :success
    # Isolation proof panel must show the tenant-side failure. Upstream
    # wording varies by build: older "table not found", current
    # 'collection "articles" does not exist'.
    assert_match(/table not found: articles|collection (&quot;|")articles(&quot;|") does not exist/, response.body)

    marker = "note #{SecureRandom.hex(3)}"
    post add_note_tenant_path(NAME), params: { body: marker }
    follow_redirect!
    assert_match(marker, response.body)
  end

  test "rejects invalid tenant names" do
    post tenants_path, params: { name: "Bad Name; DROP" }
    assert_redirected_to tenants_path
    assert_match(/Failed/, flash[:alert])
    assert_nil Tenant.find_by(id: "bad name; drop")
  end
end
