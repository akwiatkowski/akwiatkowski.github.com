require "json"

class PoisView < BaseView
  Log = ::Log.for(self)

  URL = "/pois.html"

  # Auto-POI generation constants
  AUTO_POI_CLUSTER_RADIUS_M =    500.0 # meters — merge photos within this distance
  AUTO_POI_DEDUP_DISTANCE_M = 20_000.0 # meters — skip if within this of a manual POI
  AUTO_POI_MAX_COUNT        =       20 # max auto-POIs to emit

  def initialize(context : RenderContext, @url : String = URL)
    super(context: context, url: @url)
  end

  def additional_bundles : Array(String)
    ["leaflet", "react-runtime"]
  end

  def page_css : Array(String)
    ["pois"]
  end

  def page_js : String?
    "/js/self/pois.js"
  end

  def title
    "Ciekawe miejsca"
  end

  def add_to_sitemap?
    true
  end

  def content
    data = Hash(String, String).new
    data["pois_json"] = generate_pois_json
    load_html("pois/pois", data)
  end

  private def generate_pois_json : String
    posts = context.posts
    train_stations = context.train_stations
    ideas = context.ideas
    all_photos = posts.flat_map { |p| p.published_photo_entities }
    geo_photos = all_photos.select { |p| p.exif.lat && p.exif.lon }

    # Collect manual POI locations for deduplication
    manual_poi_coords = [] of {Float64, Float64}
    posts.each do |post|
      pois = post.pois
      next unless pois
      pois.each { |poi| manual_poi_coords << {poi.lat, poi.lon} }
    end

    auto_pois = build_auto_pois(geo_photos, manual_poi_coords)

    JSON.build do |json|
      json.object do
        json.field "pois" do
          json.array do
            # Manual POIs
            posts.each do |post|
              pois = post.pois
              next unless pois
              pois.each do |poi|
                emit_manual_poi(json, poi, post, geo_photos, train_stations, ideas)
              end
            end

            # Auto-generated POIs from best photos
            auto_pois.each do |photo|
              emit_auto_poi(json, photo)
            end
          end
        end
      end
    end
  end

  private def emit_manual_poi(json, poi, post, geo_photos, train_stations, ideas)
    json.object do
      json.field("name", poi.name)
      json.field("lat", poi.lat)
      json.field("lon", poi.lon)
      json.field("type", poi.type)

      json.field("post_title", post.title)
      json.field("post_url", post.url)
      json.field("post_date", post.date)
      json.field("post_distance", (post.distance || 0.0).to_i)
      json.field("post_time_spent", (post.time_spent || 0.0).to_i)

      if poi.type == "visited"
        closest = find_closest_photo(poi, geo_photos)
        if closest
          json.field("photo_url", closest.grid_image_src)
          json.field("photo_desc", closest.desc)
        end
      end

      if poi.type == "todo"
        nearest, nearest_dist = find_nearest_station(poi, train_stations)
        if nearest
          json.field("station_name", nearest.name)
          json.field("station_lat", nearest.lat)
          json.field("station_lon", nearest.lon)
          json.field("station_time", nearest.poznan_time_distance)
          json.field("station_distance_km", (nearest_dist / 1000.0).round(1))
        end

        idea = find_nearest_idea(poi, ideas, train_stations)
        if idea
          json.field("idea_start", idea.start)
          json.field("idea_finish", idea.finish)
          json.field("idea_distance", idea.distance)
          json.field("idea_days", "#{idea.days_min}-#{idea.days_normal}")
        end
      end
    end
  end

  private def emit_auto_poi(json, photo : PhotoEntity)
    json.object do
      json.field("name", photo.desc.empty? ? "Punkt widokowy" : photo.desc)
      json.field("lat", photo.exif.lat.not_nil!)
      json.field("lon", photo.exif.lon.not_nil!)
      json.field("type", "auto")
      json.field("photo_url", photo.grid_image_src)
      json.field("photo_desc", photo.desc)
      json.field("post_title", photo.post_title)
      json.field("post_url", photo.post_url)
      json.field("post_date", photo.post_time.to_s("%Y-%m-%d"))
      json.field("points", photo.points)
    end
  end

  # Build auto-POIs: cluster best geo-tagged photos, deduplicate vs manual POIs
  private def build_auto_pois(geo_photos, manual_poi_coords) : Array(PhotoEntity)
    # Sort by points descending — best photos first
    sorted = geo_photos.select { |p| p.points > 0 }.sort_by { |p| -p.points }

    clusters = [] of PhotoEntity # representative photo per cluster

    sorted.each do |photo|
      lat = photo.exif.lat.not_nil!
      lon = photo.exif.lon.not_nil!

      # Skip if too close to a manual POI
      too_close_to_manual = manual_poi_coords.any? do |mlat, mlon|
        CrystalGpx::Point.distance(lat1: lat, lon1: lon, lat2: mlat, lon2: mlon) < AUTO_POI_DEDUP_DISTANCE_M
      end
      next if too_close_to_manual

      # Skip if too close to an already-selected cluster
      too_close_to_cluster = clusters.any? do |c|
        clat = c.exif.lat.not_nil!
        clon = c.exif.lon.not_nil!
        CrystalGpx::Point.distance(lat1: lat, lon1: lon, lat2: clat, lon2: clon) < AUTO_POI_CLUSTER_RADIUS_M
      end
      next if too_close_to_cluster

      clusters << photo
      break if clusters.size >= AUTO_POI_MAX_COUNT
    end

    clusters
  end

  private def find_closest_photo(poi, photos) : PhotoEntity?
    best = nil
    best_dist = Float64::MAX
    photos.each do |photo|
      lat = photo.exif.lat
      lon = photo.exif.lon
      next unless lat && lon
      dist = CrystalGpx::Point.distance(lat1: poi.lat, lon1: poi.lon, lat2: lat.to_f64, lon2: lon.to_f64)
      if dist < best_dist
        best_dist = dist
        best = photo
      end
    end
    best
  end

  private def find_nearest_station(poi, stations) : {TrainStationEntity?, Float64}
    best = nil
    best_dist = Float64::MAX
    stations.each do |station|
      dist = CrystalGpx::Point.distance(lat1: poi.lat, lon1: poi.lon, lat2: station.lat, lon2: station.lon)
      if dist < best_dist
        best_dist = dist
        best = station
      end
    end
    {best, best_dist}
  end

  private def find_nearest_idea(poi, ideas, stations) : IdeaEntity?
    best = nil
    best_dist = Float64::MAX
    ideas.each do |idea|
      [idea.start, idea.finish].each do |station_name|
        station = stations.find { |s| s.name == station_name }
        next unless station
        dist = CrystalGpx::Point.distance(lat1: poi.lat, lon1: poi.lon, lat2: station.lat, lon2: station.lon)
        if dist < best_dist
          best_dist = dist
          best = idea
        end
      end
    end
    # Only suggest if < 100km away
    best_dist < 100_000 ? best : nil
  end
end
