require "yaml"

require "../../models/photo_entity"
require "../../models/coord_range"

require "./const"
require "./tiles_layer"
require "./routes_layer"
require "./crop"

require "./photo_layer/all"

class Map::Main
  Log = ::Log.for(self)

  def initialize(
    @posts = Array(Tremolite::Post).new,

    @tile = Map::MapTile::Ump,
    @type = MapType::Blank,
    @zoom = DEFAULT_ZOOM,

    @post_slugs : Array(String) = Array(String).new,

    @photo_size = Map::DEFAULT_PHOTO_SIZE,
    @photos : Array(PhotoEntity) = Array(PhotoEntity),

    # selective rendering
    @render_routes : Bool = true,

    @routes_type : Map::MapRoutesType = Map::MapRoutesType::Static,

    # by default photos are linked to Post not full src of PhotoEntity
    @photo_link_to : Map::MapPhotoLinkTo = Map::MapPhotoLinkTo::LinkToPost,

    # only for dot photo map - size of colored dot
    @dot_radius = DEFAULT_DOT_RADIUS,
    # filter only photos in rectangle
    @coord_range : CoordRange? = nil,
    # enforce to render all routes points on map
    # by changing extreme coords

    # try to select best zoom
    @autozoom : Bool = false,
    # if we need to show only selected photos

    # only Poland and area
    # don't include other countries into photomaps
    # if true set default @coord_range if not set
    #
    # enable for maps which loads all photos
    @only_in_poland : Bool = true,

    # it's possible to override dimension. ex: small post map
    @custom_width : Int32 | Nil = nil,
    @custom_height : Int32 | Nil = nil
  )
    Log.info { "Start zoom=#{@zoom},post_slugs.size=#{@post_slugs.size},photos.size=#{@photos.nil? ? nil : @photos.not_nil!.size}" }

    # only used for calculating how map should be cropped
    @crop = Crop.new

    @internal_coord_range = CoordRange.new

    # if list of post slugs were provided select only for this posts
    if @post_slugs.size > 0
      all_photos = @photos.select do |photo_entity|
        @post_slugs.includes?(photo_entity.post_slug)
      end
    else
      all_photos = @photos
    end

    # select only with geo coords
    photos_w_coords = all_photos.select do |photo_entity|
      photo_entity.exif.not_nil!.lat != nil && photo_entity.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))

    # small fix to ignore photos from Switzerland because
    # it will enlarge map too much
    if @coord_range.nil? && @only_in_poland == true
      @coord_range = CoordRange.poland_area
    end

    Log.debug { "selected #{@photos.size} photos with lat/lon" }

    # ## END OF PHOTOS FILTER

    # set geo range using photos
    if @photos.size > 0
      @photos.each do |photo|
        lat = photo.exif.not_nil!.lat.not_nil!
        lon = photo.exif.not_nil!.lon.not_nil!
        @internal_coord_range.enlarge!(lat, lon)
      end

      Log.debug { "area from photos #{@internal_coord_range.to_s}" }
    end

    # enlarge coord range
    if @posts.size > 0
      array = @posts.map { |post| post.detailed_routes }.flatten.compact
      array = [array] if array.is_a?(PostRouteObject)
      routes_coord_range = PostRouteObject.array_to_coord_range(
        array: array
      )

      if routes_coord_range
        Log.debug { "routes_coord_range #{routes_coord_range}" }

        routes_coord_range = routes_coord_range.not_nil!
        # when we don't have photos near edges of route (I haven't took photo
        # soon after start riding) we need to enlarge coord range to make
        # all route point visible on map

        # TODO: check this flag
        if !@internal_coord_range.valid? # || @todo_do_not_crop_routes
          @internal_coord_range.enlarge!(routes_coord_range)
          Log.debug { "area from routes_coord_range #{@internal_coord_range.to_s}" }
        end
      end
    end

    # ## END OF POSTS

    @tiles_layer = TilesLayer.new(
      lat_min: @internal_coord_range.lat_from,
      lat_max: @internal_coord_range.lat_to,
      lon_min: @internal_coord_range.lon_from,
      lon_max: @internal_coord_range.lon_to,
      zoom: @zoom,
    )

    @routes_layer = RoutesLayer.new(
      posts: @posts,
      crop: @crop,
      tiles_layer: @tiles_layer,
      type: @routes_type,
    )

    case @type
    when MapType::PhotoGrid
      # divide map by grid cell and add photo
      @photo_layer = PhotoLayer::GridLayer.new(
        photos: @photos,
        crop: @crop,
        tiles_layer: @tiles_layer,
        photo_size: @photo_size
      )
    when MapType::PhotoDots
      # just render every photo as dot/small circle
      @photo_layer = PhotoLayer::DotsLayer.new(
        photos: @photos,
        crop: @crop,
        tiles_layer: @tiles_layer,
        photo_link_to: @photo_link_to,
        dot_radius: @dot_radius,
      )
    when Map::MapType::PhotosAssignedToRoute
      # draw route and add assigned photos located outside of route polyline
      @photo_layer = PhotoLayer::PhotosAssignedToRouteLayer.new(
        photos: @photos,
        crop: @crop,
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
        s << "<text x='#{x}' y='#{y}' font-size='smaller'>źródło: UMP</text>\n"
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
      s << @routes_layer.render_svg if @render_routes
    end

    return String.build do |s|
      cropped_width = @crop.cropped_width(@tiles_layer.map_width)
      cropped_height = @crop.cropped_height(@tiles_layer.map_height)
      crop_x = @crop.crop_x
      crop_y = @crop.crop_y

      width = cropped_width
      width = @custom_width.not_nil! if @custom_width
      height = cropped_height
      height = @custom_height.not_nil! if @custom_height

      # found that I had to calculate new heigh using aspect ratio
      # `height` is probably not used here
      aspect_ratio = @tiles_layer.map_width.to_f / @tiles_layer.map_height.to_f
      new_height = (width.to_f / aspect_ratio).to_i

      # debug snippet
      s << "<!--\n"
      s << @crop.debug_hash(@tiles_layer.map_width, @tiles_layer.map_height).to_yaml.gsub("---", "")
      s << "\n"

      s << "tiles: width=#{@tiles_layer.map_width}, height=#{@tiles_layer.map_height}\n\n"
      s << "zoom: #{@zoom}\n\n"
      s << "internal_coord_range: #{@internal_coord_range}\n\n"

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
end
