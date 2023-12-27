require "./const"
require "./tiles_layer"
require "./routes_layer"
require "./photo_layer"
require "./photo_dots_layer"
require "./photo_to_route_layer"

class Map::Base
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @tile = MapType::Ump,
    zoom = DEFAULT_ZOOM,
    @post_slugs : Array(String) = Array(String).new,
    @quant_size = DEFAULT_PHOTO_SIZE,
    # only for dot photo map - size of colored dot
    @dot_radius = DEFAULT_DOT_RADIUS,
    # filter only photos in rectangle
    @coord_range : CoordRange? = nil,
    # enforce to render all routes points on map
    # by changing extreme coords
    @do_not_crop_routes : Bool = false,
    # try to select best zoom
    @autozoom : Bool = false,
    # if we need to show only selected photos
    @photo_entities : Array(PhotoEntity)? = nil,
    # selective rendering
    @render_routes : Bool = true,
    # toggle to render photos not as grid but pointed to route
    @render_photos_out_of_route : Bool = false,
    # toggle to render photos as dots on map
    @render_photo_dots : Bool = false,
    # by default photos are linked to Post not full src of PhotoEntity
    @photo_direct_link : Bool = false,
    # animated, show routed poly line after some seconds
    @animated : Bool = false,
    # only Poland and area
    # don't include other countries into photomaps
    # if true set default @coord_range if not set
    #
    # enable for maps which loads all photos
    @limit_to_poland : Bool = true
  )
    Log.info { "Start zoom=#{zoom},post_slugs.size=#{@post_slugs.size},photo_entities.size=#{@photo_entities.nil? ? nil : @photo_entities.not_nil!.size}" }

    @internal_coord_range = CoordRange.new

    # ## PHOTOS

    if @photo_entities
      all_photos = @photo_entities.not_nil!
    else
      all_photos = @blog.data_manager.exif_db.all_flatten_photo_entities
    end

    # if list of post slugs were provided select only for this posts
    if @post_slugs.size > 0
      all_photos = all_photos.select do |photo_entity|
        @post_slugs.includes?(photo_entity.post_slug)
      end
    end

    # select only with geo coords
    photos_w_coords = all_photos.select do |photo_entity|
      photo_entity.exif.not_nil!.lat != nil && photo_entity.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))

    # small fix to ignore photos from Switzerland because
    # it will enlarge map too much
    if @coord_range.nil? && @limit_to_poland == true
      @coord_range = CoordRange.poland_area
    end

    # select only photos which are within @coord_range
    if @coord_range
      photos_w_coords = photos_w_coords.select do |photo_entity|
        @coord_range.not_nil!.is_within?(
          lat: photo_entity.exif.not_nil!.lat.not_nil!,
          lon: photo_entity.exif.not_nil!.lon.not_nil!,
        )
      end
    end

    @photos = photos_w_coords.as(Array(PhotoEntity))

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

    # ## POSTS (for routes)

    posts = @blog.post_collection.posts.sort.as(Array(Tremolite::Post))

    # filter posts photos
    # routes are taken from this later
    if @post_slugs.size > 0
      Log.debug { "pre post_slug filter #{posts.size}" }

      posts = posts.select do |post|
        @post_slugs.includes?(post.slug)
      end

      Log.debug { "after post_slug filter #{posts.size}" }
    end

    # select only posts with routes/coords
    @posts = posts.select do |post|
      post.detailed_routes.size > 0
    end.as(Array(Tremolite::Post))

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

        if !@internal_coord_range.valid? || @do_not_crop_routes
          @internal_coord_range.enlarge!(routes_coord_range)
          Log.debug { "area from routes_coord_range #{@internal_coord_range.to_s}" }
        end
      end
    end

    # ## END OF POSTS

    if @coord_range
      @internal_coord_range = @coord_range.not_nil!
      Log.debug { "coord_range was provided" }
    end

    Log.debug { "area #{@internal_coord_range.to_s}" }

    # only towns with coords
    @towns = @blog.data_manager.not_nil!.towns.not_nil!.select do |town|
      town.lat && town.lon
    end.as(Array(TownEntity))

    Log.debug { "#{@posts.size} posts" }
    Log.debug { "#{@towns.size} towns" }

    # tiles will be first initial

    @tiles_layer = TilesLayer.new(
      lat_min: @internal_coord_range.lat_from,
      lat_max: @internal_coord_range.lat_to,
      lon_min: @internal_coord_range.lon_from,
      lon_max: @internal_coord_range.lon_to,
      zoom: zoom,
    )

    @routes_layer = RoutesLayer.new(
      posts: @posts,
      tiles_layer: @tiles_layer,
      animated: @animated,
    )

    # TODO: change from boolean to some kind of type or strategy
    if @render_photos_out_of_route
      # for post photo map we render photo assigned to route
      @photo_layer = PhotoToRouteLayer.new(
        photos: @photos,
        posts: @posts,
        tiles_layer: @tiles_layer,
        image_size: @quant_size,
        photo_direct_link: @photo_direct_link,
      )
    elsif @render_photo_dots
      # detailed map with dots as photos
      @photo_layer = PhotoDotsLayer.new(
        photos: @photos,
        tiles_layer: @tiles_layer,
        photo_direct_link: @photo_direct_link,
        dot_radius: @dot_radius,
      )
    else
      # else, render photo grid
      @photo_layer = PhotoLayer.new(
        photos: @photos,
        tiles_layer: @tiles_layer,
        quant_size: @quant_size
      )
    end
  end

  def to_svg
    return String.build do |s|
      s << "<svg height='#{@tiles_layer.map_height}' width='#{@tiles_layer.map_width}' "
      s << "viewBox='#{@tiles_layer.cropped_x} #{@tiles_layer.cropped_y} #{@tiles_layer.cropped_width} #{@tiles_layer.cropped_height}' "
      s << "class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' >\n"

      s << @tiles_layer.render_svg
      s << @photo_layer.render_svg
      s << @routes_layer.render_svg if @render_routes

      s << "</svg>\n"
      Log.debug { "svg done" }
    end
  end
end
