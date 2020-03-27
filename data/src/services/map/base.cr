require "./const"
require "./tiles_layer"
require "./routes_layer"
require "./photo_layer"

class Map::Base
  def initialize(
    @blog : Tremolite::Blog,
    @tile = MapType::Ump,
    @zoom = DEFAULT_ZOOM
  )
    @logger = @blog.logger.as(Logger)
    @logger.info("#{self.class}: Start")

    # select only photos with lat/lon
    @photos = @blog.data_manager.not_nil!.photos.not_nil!.select do |photo|
      photo.exif.not_nil!.lat != nil && photo.exif.not_nil!.lon != nil
    end.as(Array(PhotoEntity))
    @logger.info("#{self.class}: selected #{@photos.size} photos with lat/lon")

    # if not enouh photos
    if @photos.size <= 2
      @logger.warn("#{self.class}: not enough photos")
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
    @logger.info("#{self.class}: area #{@lat_min}-#{@lat_max},#{@lon_min}-#{@lon_max}")

    # store here to speed up
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # only towns with coords
    @towns = @blog.data_manager.not_nil!.towns.not_nil!.select do |town|
      town.lat && town.lon
    end.as(Array(TownEntity))
    @logger.info("#{self.class}: #{@posts.size} posts")
    @logger.info("#{self.class}: #{@towns.size} towns")

    # tiles will be first initial
    @tiles_layer = TilesLayer.new(
      lat_min: @lat_min,
      lat_max: @lat_max,
      lon_min: @lon_min,
      lon_max: @lon_max,
      zoom: 10,
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
    )
  end

  def to_s
    return String.build do |s|
      s << "<svg height='#{@tiles_layer.map_height}' width='#{@tiles_layer.map_width}' class='photo-map-tiles' xmlns='http://www.w3.org/2000/svg'>\n"
      s << @tiles_layer.render_svg
      s << @photo_layer.render_svg
      s << @routes_layer.render_svg
      s << "</svg>\n"
    end
  end
end
