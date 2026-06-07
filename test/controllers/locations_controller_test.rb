require "test_helper"

# Locations sidestep the spatial engine (BUG-011) by storing
# lat/lon FLOAT columns in a document_strict collection and computing
# haversine in Ruby.
class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup { skip_if_daemon_down! }

  test "GET /locations returns 200" do
    get locations_path
    assert_response :success
  end

  test "GET /locations/map is a legacy 301 redirect to /locations" do
    get map_locations_path
    assert_redirected_to locations_path
  end

  test "GET /locations/near with lat/lon returns 200" do
    get near_locations_path, params: { lat: 40.7128, lon: -74.0060, radius_km: 100 }
    assert_response :success
  end
end
