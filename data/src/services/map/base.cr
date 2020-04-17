require "./const"
require "./tiles_layer"
require "./routes_layer"
require "./photo_layer"

class Map::Base
  def initialize(
    @blog : Tremolite::Blog,
    @tile = MapType::Ump,
    zoom = DEFAULT_ZOOM,
    @post_slugs : Array(String) = Array(String).new,
    @quant_size = DEFAULT_PHOTO_SIZE,
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
  )
    @logger = @blog.logger.as(Logger)
    @logger.info("#{self.class}: Start")

    @internal_coord_range = CoordRange.new

    ### PHOTOS

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

    @logger.info("#{self.class}: selected #{@photos.size} photos with lat/lon")

    ### END OF PHOTOS FILTER

    # set geo range using photos
    if @photos.size > 0
      @photos.each do |photo|
        lat = photo.exif.not_nil!.lat.not_nil!
        lon = photo.exif.not_nil!.lon.not_nil!
        @internal_coord_range.enlarge!(lat, lon)
      end

      @logger.info("#{self.class}: area from photos #{@internal_coord_range.to_s}")
    end

    ### POSTS (for routes)

    posts = @blog.post_collection.posts.sort.as(Array(Tremolite::Post))

    # filter posts photos
    # routes are taken from this later
    if @post_slugs.size > 0
      @logger.debug("#{self.class}: pre post_slug filter #{posts.size}")

      posts = posts.select do |post|
        @post_slugs.includes?(post.slug)
      end

      @logger.debug("#{self.class}: after post_slug filter #{posts.size}")
    end

    # select only posts with routes/coords
    @posts = posts.select do |post|
      post.detailed_routes.size > 0
    end.as(Array(Tremolite::Post))

    # enlarge coord range
    if @posts.size > 0
      array = @posts.map {|post| post.detailed_routes }.flatten.compact
      array = [array] if array.is_a?(PostRouteObject)
      routes_coord_range = PostRouteObject.array_to_coord_range(
        array: array
      )

      if routes_coord_range
        @logger.debug("#{self.class}: routes_coord_range #{routes_coord_range}")

        routes_coord_range = routes_coord_range.not_nil!
        # when we don't have photos near edges of route (I haven't took photo
        # soon after start riding) we need to enlarge coord range to make
        # all route point visible on map

        if !@internal_coord_range.valid? || @do_not_crop_routes
          @internal_coord_range.enlarge!(routes_coord_range)
          @logger.debug("#{self.class}: area from routes_coord_range #{@internal_coord_range.to_s}")
        end
      end
    end

    ### END OF POSTS

    if @coord_range
      @internal_coord_range = @coord_range.not_nil!
      @logger.debug("#{self.class}: coord_range was provided")
    end

    @logger.info("#{self.class}: area #{@internal_coord_range.to_s}")

    # only towns with coords
    @towns = @blog.data_manager.not_nil!.towns.not_nil!.select do |town|
      town.lat && town.lon
    end.as(Array(TownEntity))
    @logger.info("#{self.class}: #{@posts.size} posts")
    @logger.info("#{self.class}: #{@towns.size} towns")

    # tiles will be first initial

    @tiles_layer = TilesLayer.new(
      lat_min: @internal_coord_range.lat_from,
      lat_max: @internal_coord_range.lat_to,
      lon_min: @internal_coord_range.lon_from,
      lon_max: @internal_coord_range.lon_to,
      zoom: zoom,
      logger: @logger,
    )

    @routes_layer = RoutesLayer.new(
      posts: @posts,
      tiles_layer: @tiles_layer,
      logger: @logger,
    )

    @photo_layer = PhotoLayer.new(
      photos: @photos,
      tiles_layer: @tiles_layer,
      logger: @logger,
      quant_size: @quant_size
    )
  end

  def to_svg
    svg_content = String.build do |s|
      s << @tiles_layer.render_svg
      s << @photo_layer.render_svg
      s << @routes_layer.render_svg if @render_routes
      @logger.debug("#{self.class}: svg content done")
    end

    return String.build do |s|
      s << "<svg height='#{@tiles_layer.map_height}' width='#{@tiles_layer.map_width}' "
      s << "viewBox='#{@tiles_layer.cropped_x} #{@tiles_layer.cropped_y} #{@tiles_layer.cropped_width} #{@tiles_layer.cropped_height}' "
      s << "class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg' >\n"
      # first we need render all to know about padding
      s << svg_content
      s << "</svg>\n"
      @logger.debug("#{self.class}: svg done")
    end
  end
end
