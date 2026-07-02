require "./map_config"
require "./map_context"
require "./map_result"
require "./photo_selection"

class Map::MapPipeline
  Log = ::Log.for(self)

  include PhotoSelection

  def initialize(@config : MapConfig, @context : MapContext)
  end

  def compute : MapResult
    # Step 1: Filter posts and photos
    posts = filter_posts(@context.posts)
    photos_w_coords = filter_photos_with_coords(@context.photos)

    # Step 2: Build CoordCrop from filtered data
    coord_crop = Crop::CoordCrop.new(
      type: @config.coord_crop_type,
      fixed_coord_range: @config.fixed_coord_range
    )

    photos_w_coords.each do |photo|
      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!
      coord_crop.photo(lat, lon)
    end

    route_objects = collect_route_objects(posts)
    route_objects.each do |route_object|
      route_object.route.each do |coord|
        coord_crop.route(coord[0], coord[1])
      end
    end

    # Step 3: Auto-zoom if configured
    zoom = @config.zoom
    debug = Hash(String, String).new

    if @config.autozoom_width
      autozoom_data = TilesLayer.ideal_zoom_for_photo_distance(
        coord_range: coord_crop.coord_range,
        distance: @config.autozoom_width.not_nil!
      )
      zoom = autozoom_data[:zoom]
    end

    # Step 4: Create TilesLayer (projection)
    tiles_layer = TilesLayer.new(
      lat_min: coord_crop.coord_range.lat_from,
      lat_max: coord_crop.coord_range.lat_to,
      lon_min: coord_crop.coord_range.lon_from,
      lon_max: coord_crop.coord_range.lon_to,
      zoom: zoom,
    )

    # Step 5: Compute raster crop tracking
    raster_crop = Crop::RasterCrop.new(type: @config.coord_crop_type)

    # Step 6: Compute tile info
    tiles = compute_tiles(tiles_layer)

    # Step 7: Compute route polylines
    route_polylines = compute_route_polylines(posts, route_objects, tiles_layer, raster_crop)

    # Step 8: Compute photo layout
    photo_elements = compute_photo_elements(photos_w_coords, posts, tiles_layer, raster_crop)

    # Step 9: Compute ViewBox
    cropped_width = raster_crop.cropped_width(tiles_layer.map_width)
    cropped_height = raster_crop.cropped_height(tiles_layer.map_height)
    crop_x = raster_crop.crop_x
    crop_y = raster_crop.crop_y

    view_box = ViewBox.new(
      x: crop_x,
      y: crop_y,
      width: cropped_width,
      height: cropped_height
    )

    MapResult.new(
      tiles: tiles,
      tile_source: @config.tile,
      route_polylines: route_polylines,
      photo_elements: photo_elements,
      view_box: view_box,
      map_width: tiles_layer.map_width,
      map_height: tiles_layer.map_height,
      center_lat: tiles_layer.map_lat_center,
      center_lon: tiles_layer.map_lon_center,
      zoom: zoom,
      custom_width: @config.custom_width,
      custom_height: @config.custom_height,
      debug: debug,
    )
  end

  private def filter_posts(posts : Array(Tremolite::Post)) : Array(Tremolite::Post)
    posts.sort.select { |post| post.detailed_routes.size > 0 }
  end

  private def filter_photos_with_coords(photos : Array(PhotoEntity)) : Array(PhotoEntity)
    photos.select do |pe|
      pe.exif.not_nil!.lat != nil && pe.exif.not_nil!.lon != nil
    end
  end

  private def collect_route_objects(posts : Array(Tremolite::Post)) : Array(PostRouteObject)
    route_objects = posts.map { |post| post.detailed_routes }.flatten.compact
    route_objects = [route_objects] if route_objects.is_a?(PostRouteObject)
    route_objects += @context.routes
    route_objects.as(Array(PostRouteObject))
  end

  private def compute_tiles(tiles_layer : TilesLayer) : Array(TileInfo)
    tiles = Array(TileInfo).new
    ((tiles_layer.x_tile1)..(tiles_layer.x_tile2)).each do |tile_x|
      ((tiles_layer.y_tile1)..(tiles_layer.y_tile2)).each do |tile_y|
        relative_x = tile_x - tiles_layer.x_tile1
        relative_y = tile_y - tiles_layer.y_tile1
        x = relative_x * TILE_WIDTH
        y = relative_y * TILE_WIDTH
        url = "/tiles/ump/#{tiles_layer.zoom}/#{tile_x}/#{tile_y}.png"
        tiles << TileInfo.new(pixel_x: x, pixel_y: y, url: url)
      end
    end
    tiles
  end

  private def compute_route_polylines(
    posts : Array(Tremolite::Post),
    route_objects : Array(PostRouteObject),
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
  ) : Array(RoutePolyline)
    return Array(RoutePolyline).new unless @config.routes_type == MapRoutesType::Static || @config.routes_type == MapRoutesType::Animated

    animated = @config.routes_type == MapRoutesType::Animated
    polylines = Array(RoutePolyline).new
    route_colors = @context.route_colors

    # Routes from posts
    posts.each do |post|
      post.detailed_routes.each do |route_object|
        polyline = route_object_to_polyline(route_object, tiles_layer, raster_crop, route_colors, animated)
        polylines << polyline if polyline
      end
    end

    # Standalone routes
    @context.routes.each do |route_object|
      polyline = route_object_to_polyline(route_object, tiles_layer, raster_crop, route_colors, animated)
      polylines << polyline if polyline
    end

    polylines
  end

  private def route_object_to_polyline(
    route_object : PostRouteObject,
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
    route_colors : RouteColors,
    animated : Bool,
  ) : RoutePolyline?
    return nil unless route_colors.has_type?(route_object.type)

    color_rgb = route_colors.color_rgb_for(route_object.type) || "0,0,0"
    geo_coords = route_object.route.as(SingleRouteObject)
    return nil if geo_coords.size < 2

    points = geo_coords.map do |geo_coord|
      lat, lon = geo_coord
      x, y = tiles_layer.in_map_position_from_geo_coords(lat_deg: lat, lon_deg: lon)
      raster_crop.route(x.to_i, y.to_i)
      {x.to_i, y.to_i}
    end

    RoutePolyline.new(points: points, color_rgb: color_rgb, animated: animated)
  end

  private def compute_photo_elements(
    photos : Array(PhotoEntity),
    posts : Array(Tremolite::Post),
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
  ) : Array(PhotoElement)
    case @config.type
    when MapType::PhotoGrid
      compute_grid_elements(photos, tiles_layer, raster_crop)
    when MapType::PhotoDots
      compute_dot_elements(photos, tiles_layer, raster_crop)
    when MapType::PhotosAssignedToRoute
      compute_assigned_elements(photos, posts, tiles_layer, raster_crop)
    else
      Array(PhotoElement).new
    end
  end

  private def compute_grid_elements(
    photos : Array(PhotoEntity),
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
  ) : Array(PhotoElement)
    elements = Array(PhotoElement).new
    photo_size = @config.photo_size

    # Build spatial index once — O(n) — then each cell query is O(1) avg
    spatial_index = SpatialIndex.new(photos)

    x = 0
    while x <= tiles_layer.map_width
      y = 0
      while y <= tiles_layer.map_height
        lat1, lon1 = tiles_layer.geo_coords_from_map_pixel_position(x, y)
        lat2, lon2 = tiles_layer.geo_coords_from_map_pixel_position(x + photo_size, y + photo_size)

        selected = spatial_index.query(
          lat_min: lat2, lat_max: lat1, lon_min: lon1, lon_max: lon2)

        if selected.size > 0
          photo = select_suitable_photo(selected)
          if photo
            raster_crop.square_photo(x: x, y: y, size: photo_size)
            link_url = @config.photo_link_to == MapPhotoLinkTo::LinkToPost ? photo.post_url : photo.full_image_src
            elements << GridPhotoElement.new(
              x: x, y: y, size: photo_size,
              image_src: photo.grid_image_src,
              link_url: link_url
            )
          end
        end
        y += photo_size
      end
      x += photo_size
    end

    elements
  end

  private def compute_dot_elements(
    photos : Array(PhotoEntity),
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
  ) : Array(PhotoElement)
    elements = Array(PhotoElement).new

    photos.each do |photo|
      next if photo.exif.not_nil!.lat.nil? || photo.exif.not_nil!.lon.nil?

      x, y = tiles_layer.in_map_position_from_geo_coords(
        lat_deg: photo.exif.not_nil!.lat.not_nil!,
        lon_deg: photo.exif.not_nil!.lon.not_nil!
      )

      raster_crop.photo_dot(x.to_i, y.to_i)

      day_of_year = photo.exif.not_nil!.time.not_nil!.day_of_year
      color = PhotoSelection.day_of_year_to_color(day_of_year)
      photo_url = photo.full_image_src

      elements << DotElement.new(x: x.to_i, y: y.to_i, color: color, photo_url: photo_url)
    end

    elements
  end

  private def compute_assigned_elements(
    photos : Array(PhotoEntity),
    posts : Array(Tremolite::Post),
    tiles_layer : TilesLayer,
    raster_crop : Crop::RasterCrop,
  ) : Array(PhotoElement)
    # Delegate to the existing PhotosAssignedToRouteLayer for its complex
    # placement algorithm, then extract the data
    layer = PhotoLayer::PhotosAssignedToRouteLayer.new(
      photos: photos,
      raster_crop: raster_crop,
      posts: posts,
      tiles_layer: tiles_layer,
      image_size: @config.photo_size,
      photo_link_to: @config.photo_link_to,
    )
    layer.to_photo_elements
  end
end
