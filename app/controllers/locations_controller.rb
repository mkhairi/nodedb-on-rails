class LocationsController < ApplicationController
  before_action :set_location, only: %i[show destroy]

  def index
    @locations = Location.all.to_a
  end

  def show; end

  def new
    @location = Location.new(lat: 40.7128, lon: -74.0060)
  end

  def create
    @location = Location.new(location_params)
    if @location.save
      redirect_to locations_path, notice: "Location pinned."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    redirect_to locations_path, notice: "Location removed.", status: :see_other
  end

  # Legacy /locations/map route — combined into the index. Redirect.
  def map
    redirect_to locations_path, status: :moved_permanently
  end

  # NodeDB's spatial read-side predicates (ST_DWithin, ST_Distance)
  # remain unusable on current upstream (writes and raw GeoJSON reads
  # work), so radius search is done in Ruby with haversine over the
  # AR-loaded collection.
  def near
    @lat    = (params[:lat].presence || 40.7128).to_f
    @lon    = (params[:lon].presence || -74.0060).to_f
    @meters = (params[:meters].presence || 5_000_000).to_f
    @hits = Location.all.map do |loc|
      d = haversine(@lat, @lon, loc.lat, loc.lon)
      OpenStruct.new(id: loc.id, name: loc.name, lat: loc.lat, lon: loc.lon, distance_m: d)
    end.select { |h| h.distance_m <= @meters }.sort_by(&:distance_m)
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.expect(location: %i[name lat lon])
  end

  def haversine(lat1, lon1, lat2, lon2)
    r = 6_371_000.0
    to_rad = ->(d) { d * Math::PI / 180.0 }
    dlat = to_rad.(lat2 - lat1)
    dlon = to_rad.(lon2 - lon1)
    a = Math.sin(dlat / 2)**2 +
        Math.cos(to_rad.(lat1)) * Math.cos(to_rad.(lat2)) * Math.sin(dlon / 2)**2
    2 * r * Math.asin(Math.sqrt(a))
  end
end
