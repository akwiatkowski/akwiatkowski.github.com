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
  )
    @logger = @blog.logger.as(Logger)
    @logger.info("#{self.class}: Start")

    # select only photos with lat/lon
    all_photos = @blog.data_manager.exif_db.all_flatten_photo_entities

    # if list of post slugs were provided select only for this posts
    if @post_slugs.size > 0
      all_photos = all_photos.select do |photo_entity|
        @post_slugs.includes?(photo_entity.post_slug)
      end
    end

    photos_w_coords = all_photos.select do |photo_entity|
      photo_entity.exif.not_nil!.lat != nil && photo_entity.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))

    if @coord_range
      photos_w_coords = photos_w_coords.select do |photo_entity|
        @coord_range.not_nil!.is_within?(
          lat: photo_entity.exif.not_nil!.lat.not_nil!,
          lon: photo_entity.exif.not_nil!.lon.not_nil!,
        )
      end
    end

    # end of filtering
    @photos = photos_w_coords.as(Array(PhotoEntity))

    @logger.info("#{self.class}: selected #{@photos.size} photos with lat/lon")

    # if not enouh photos
    if @photos.size <= 2
      @logger.warn("#{self.class}: not enough photos")
      raise NotEnoughPhotos.new
    end

    # assign at this moment to have not nil value
    @lat_min = @photos.first.exif.not_nil!.lat.not_nil!.as(Float64)
    @lat_max = @lat_min.as(Float64)

    @lon_min = @photos.first.exif.not_nil!.lon.not_nil!.as(Float64)
    @lon_max = @lon_min.as(Float64)

    # @lat_min, @lat_max are sorted
    @photos.each do |photo|
      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!

      @lat_min = lat if lat < @lat_min
      @lon_min = lon if lon < @lon_min

      @lat_max = lat if lat > @lat_max
      @lon_max = lon if lon > @lon_max
    end

    # store here to speed up
    @posts = @blog.post_collection.posts.sort.as(Array(Tremolite::Post))

    # filter posts photos
    # routes are taken from this later
    if @post_slugs.size > 0
      @logger.debug("#{self.class}: pre post_slug filter #{@posts.size}")

      @posts = @posts.select do |post|
        @post_slugs.includes?(post.slug)
      end

      @logger.debug("#{self.class}: after post_slug filter #{@posts.size}")
    end

    # select only posts with routes/coords
    @posts = @posts.select do |post|
      post.detailed_routes.size > 0
    end

    # use post routes to change extreme ranges
    if @posts.size > 0 && @do_not_crop_routes
      coord_ranges = @posts.map do |post|
        PostRouteObject.array_to_coord_range(
          array: post.coords.not_nil!,
                  # lets accept all types for now
          # only_types: ["hike", "bicycle", "train", "car", "air"]
)
      end.compact

      # uglier sum, but don't want to define CoordRange.zero
      coord_range = coord_ranges.first
      (1...coord_ranges.size).each do |i|
        coord_range += coord_ranges[i]
      end

      # TODO refactor 4 variables into CoordRange
      @lat_min = coord_range.lat_from if coord_range.lat_from < @lat_min
      @lon_min = coord_range.lon_from if coord_range.lon_from < @lon_min

      @lat_max = coord_range.lat_to if coord_range.lat_to > @lat_max
      @lon_max = coord_range.lon_to if coord_range.lon_to > @lon_max
    end

    @logger.info("#{self.class}: area #{@lat_min}-#{@lat_max},#{@lon_min}-#{@lon_max}")

    # only towns with coords
    @towns = @blog.data_manager.not_nil!.towns.not_nil!.select do |town|
      town.lat && town.lon
    end.as(Array(TownEntity))
    @logger.info("#{self.class}: #{@posts.size} posts")
    @logger.info("#{self.class}: #{@towns.size} towns")

    # tiles will be first initial

    ideal = TilesLayer.ideal_zoom(
      CoordRange.new(
        lat_from: @lat_min,
        lat_to: @lat_max,
        lon_from: @lon_min,
        lon_to: @lon_max
      )
    )

    @tiles_layer = TilesLayer.new(
      lat_min: @lat_min,
      lat_max: @lat_max,
      lon_min: @lon_min,
      lon_max: @lon_max,
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
      s << @routes_layer.render_svg
    end

    return String.build do |s|
      s << "<svg height='#{@tiles_layer.map_height}' width='#{@tiles_layer.map_width}' "
      s << "viewBox='#{@tiles_layer.cropped_x} #{@tiles_layer.cropped_y} #{@tiles_layer.cropped_width} #{@tiles_layer.cropped_height}' "
      s << "class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg' >\n"
      # first we need render all to know about padding
      s << svg_content
      s << "</svg>\n"
    end
  end
end
