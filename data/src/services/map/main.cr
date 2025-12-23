require "yaml"

require "../../models/photo_entity"
require "../../models/coord_range"

require "./crop/raster_crop"
require "./crop/coord_crop"

require "./const"
require "./tiles_layer"
require "./routes_layer"

require "./link_generator"

require "./photo_layer/all"

class Map::Main
  Log = ::Log.for(self)

  def initialize(
    @posts = Array(Tremolite::Post).new,
    @routes = Array(PostRouteObject).new,

    @tile = Map::MapTile::Ump,
    @type = MapType::Blank,
    @zoom = DEFAULT_ZOOM,

    @photo_size = Map::DEFAULT_PHOTO_SIZE,
    @photos : Array(PhotoEntity) = Array(PhotoEntity).new,

    # selective rendering
    @render_routes : Bool = true,

    @routes_type : Map::MapRoutesType = Map::MapRoutesType::Static,

    # by default photos are linked to Post not full src of PhotoEntity
    @photo_link_to : Map::MapPhotoLinkTo = Map::MapPhotoLinkTo::LinkToPost,

    # only for dot photo map - size of colored dot
    @dot_radius = DEFAULT_DOT_RADIUS,

    @coord_crop_type : Map::CoordCropType = Map::CoordCropType::PhotoAndRouteCrop,

    # it's possible to override dimension. ex: small post map
    @custom_width : Int32 | Nil = nil,
    @custom_height : Int32 | Nil = nil,

    # new approach to autozoom
    @autozoom_width : Int32? = nil,
    @autozoom_height : Int32? = nil,

    # if set use this value and ignore all calculations
    # used for voivodeship where coords are fixed
    @fixed_coord_range : CoordRange? = nil,
  )
    Log.info { "Start zoom=#{@zoom}, posts.size=#{@posts.size}, photos.size=#{@photos.nil? ? nil : @photos.not_nil!.size}, posts: #{@posts[0..6].map { |post| post.date.to_s }.join(",")} " }
    # just to make sure log info is rendered
    sleep(Time::Span.new(nanoseconds: 1))

    # only used for calculating how output map should be cropped
    @raster_crop = Crop::RasterCrop.new(type: @coord_crop_type)
    # only used for calculating what part of map is important
    # ex: crop for only route
    @coord_crop = Crop::CoordCrop.new(
      type: @coord_crop_type,
      fixed_coord_range: @fixed_coord_range
    )

    # select only with geo coords
    photos_w_coords = @photos.select do |photo_entity|
      photo_entity.exif.not_nil!.lat != nil && photo_entity.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))

    Log.debug { "selected #{@photos.size} photos with lat/lon" }

    # ## END OF PHOTOS FILTER

    # set geo range using photos
    if @photos.size > 0
      @photos.each do |photo|
        next if photo.exif.not_nil!.lat.nil? || photo.exif.not_nil!.lon.nil?

        lat = photo.exif.not_nil!.lat.not_nil!
        lon = photo.exif.not_nil!.lon.not_nil!
        @coord_crop.photo(lat, lon)
      end

      Log.debug { "area from photos #{@coord_crop.coord_range.to_s}" }
    end

    route_objects = Array(PostRouteObject).new

    # enlarge coord range
    if @posts.size > 0
      route_objects = @posts.map { |post| post.detailed_routes }.flatten.compact
      route_objects = [route_objects] if route_objects.is_a?(PostRouteObject)
    end

    # inject routes w/o posts
    route_objects += @routes

    # TODO: add a way to truncate routes which utilize multiple voivodeships

    route_objects.each do |route_object|
      route_object.route.each do |coord|
        lat = coord[0]
        lon = coord[1]
        @coord_crop.route(lat, lon)
      end
    end

    # routes_coord_range = PostRouteObject.array_to_coord_range(
    #   array: array
    # )
    #
    # if routes_coord_range
    #   Log.debug { "routes_coord_range #{routes_coord_range}" }
    #
    #   routes_coord_range = routes_coord_range.not_nil!
    #   # when we don't have photos near edges of route (I haven't took photo
    #   # soon after start riding) we need to enlarge coord range to make
    #   # all route point visible on map
    #
    #   # TODO: check this flag
    #   if !@internal_coord_range.valid? # || @todo_do_not_crop_routes
    #     @internal_coord_range.enlarge!(routes_coord_range)
    #     Log.debug { "area from routes_coord_range #{@internal_coord_range.to_s}" }
    #   end
    # end

    # direct passing of route data

    # # new calculation of autozoom

    @debug_distance_processed_zooms = Hash(Int32, Float64).new
    @debug_possible_zooms = Hash(Int32, NamedTuple(x: Int32, y: Int32, diagonal: Int32)).new

    if @autozoom_width
      autozoom_data = TilesLayer.ideal_zoom_for_photo_distance(
        coord_range: @coord_crop.coord_range,
        distance: @autozoom_width.not_nil!
      )

      @zoom = autozoom_data[:zoom].not_nil!
      @debug_distance_processed_zooms = autozoom_data[:distance_processed_zooms]
      @debug_possible_zooms = autozoom_data[:possible_zooms]
    end

    # ## END OF POSTS

    @tiles_layer = TilesLayer.new(
      lat_min: @coord_crop.coord_range.lat_from,
      lat_max: @coord_crop.coord_range.lat_to,
      lon_min: @coord_crop.coord_range.lon_from,
      lon_max: @coord_crop.coord_range.lon_to,
      zoom: @zoom,
    )

    @routes_layer = RoutesLayer.new(
      posts: @posts,
      routes: @routes,
      raster_crop: @raster_crop,
      tiles_layer: @tiles_layer,
      type: @routes_type,
    )

    case @type
    when MapType::PhotoGrid
      # divide map by grid cell and add photo
      @photo_layer = PhotoLayer::GridLayer.new(
        photos: @photos,
        raster_crop: @raster_crop,
        tiles_layer: @tiles_layer,
        photo_size: @photo_size
      )
    when MapType::PhotoDots
      # just render every photo as dot/small circle
      @photo_layer = PhotoLayer::DotsLayer.new(
        photos: @photos,
        raster_crop: @raster_crop,
        tiles_layer: @tiles_layer,
        photo_link_to: @photo_link_to,
        dot_radius: @dot_radius,
      )
    when Map::MapType::PhotosAssignedToRoute
      # draw route and add assigned photos located outside of route polyline
      @photo_layer = PhotoLayer::PhotosAssignedToRouteLayer.new(
        photos: @photos,
        raster_crop: @raster_crop,
        posts: @posts,
        tiles_layer: @tiles_layer,
        image_size: @photo_size,
        photo_link_to: @photo_link_to,
      )
    else # ex: MapType::Blank
      # do nothing here
      @photo_layer = PhotoLayer::BlankLayer.new
    end
  end

  def licence_text
    x = 5
    y = 20

    lat = @tiles_layer.map_lat_center
    lon = @tiles_layer.map_lon_center

    # sorry guys for not adding credits before
    # you know, a lot of work :)
    if @tile == Map::MapTile::Ump
      return String.build do |s|
        s << "\n"
        s << "<svg id='photo-map-licence'>\n"
        s << "<a href='https://mapa.ump.waw.pl/ump-www/?zoom=#{@zoom}&amp;lat=#{lat}&amp;lon=#{lon}' target='_blank'>\n"
        s << "<text x='#{x}' y='#{y}' font-size='smaller'>mapa z UMP-pcPL</text>\n"
        s << "</a>\n"
        s << "</svg>\n"
      end
    end

    return String.new
  end

  def to_svg
    # run here to calculate all points for padding
    inner_svg = String.build do |s|
      s << @tiles_layer.render_svg
      s << @photo_layer.render_svg
      s << @routes_layer.render_svg if render_routes?
    end

    return String.build do |s|
      cropped_width = @raster_crop.cropped_width(@tiles_layer.map_width)
      cropped_height = @raster_crop.cropped_height(@tiles_layer.map_height)
      crop_x = @raster_crop.crop_x
      crop_y = @raster_crop.crop_y

      width = cropped_width
      width = @custom_width.not_nil! if @custom_width
      height = cropped_height
      height = @custom_height.not_nil! if @custom_height

      # found that I had to calculate new heigh using aspect ratio
      # `height` is probably not used here

      # results is not as I intended
      # found after debuging, 0 margin, ...
      # aspect_ratio = @tiles_layer.map_width.to_f / @tiles_layer.map_height.to_f
      # new_height = (width.to_f / aspect_ratio).to_i

      aspect_ratio = cropped_width.to_f / cropped_height.to_f
      new_height = (width.to_f / aspect_ratio).to_i

      # debug snippet
      s << "<!--\n"
      s << @raster_crop.debug_hash(@tiles_layer.map_width, @tiles_layer.map_height).to_yaml.gsub("---", "")
      s << "- tiles -\n"
      s << @tiles_layer.debug_hash.to_yaml.gsub("---", "")
      s << "\n"

      s << "tiles: width=#{@tiles_layer.map_width}, height=#{@tiles_layer.map_height}\n\n"
      s << "zoom: #{@zoom}\n\n"
      s << "distance_processed_zooms: #{@debug_distance_processed_zooms.to_yaml.gsub("---", "")}\n\n"
      s << "possible_zooms: #{@debug_possible_zooms.to_yaml.gsub("---", "")}\n\n"

      s << "-->\n"

      # wrapper for autoscalling
      s << "<svg preserveAspectRatio='xMinYMin meet' viewBox='0 0 #{width} #{new_height}' "
      s << "xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>\n"

      # map
      s << "<svg width='#{width}' height='#{new_height}' "
      s << "viewBox='#{crop_x} #{crop_y} #{cropped_width} #{cropped_height}' "
      s << "class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' >\n"

      s << inner_svg

      s << "</svg>\n"

      # licence stuff is kind of separated
      s << licence_text

      s << "</svg>\n"
      Log.debug { "svg done" }
    end
  end

  def render_routes?
    return @routes_type == MapRoutesType::Static || @routes_type == MapRoutesType::Animated
  end
end
