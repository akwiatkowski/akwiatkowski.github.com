require "./const"
require "./tiles_layer"
require "./routes_layer"

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
    @min_lat = @photos.first.exif.not_nil!.lat.not_nil!.as(Float64)
    @max_lat = @min_lat.as(Float64)

    @min_lon = @photos.first.exif.not_nil!.lon.not_nil!.as(Float64)
    @max_lon = @min_lon.as(Float64)

    @photos.each do |photo|
      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!

      @min_lat = lat if lat < @min_lat
      @min_lon = lon if lon < @min_lon

      @max_lat = lat if lat > @max_lat
      @max_lon = lon if lon > @max_lon
    end
    @logger.info("#{self.class}: area #{@min_lat},#{@min_lon} - #{@max_lat},#{@max_lon} (lat,lon)")

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
      min_lat: @min_lat,
      max_lat: @max_lat,
      min_lon: @min_lon,
      max_lon: @max_lon,
      zoom: 10,
      logger: @logger,
    )

    @routes_layer = RoutesLayer.new(
      posts: @posts,
      tiles_layer: @tiles_layer,
    )
  end

  def to_s
    return String.build do |s|
      s << "<svg height='#{@tiles_layer.map_height}' width='#{@tiles_layer.map_width}' class='photo-map-tiles'>\n"
      s << @tiles_layer.render_svg
      s << @routes_layer.render_svg
      s << "</svg>\n"
    end
  end
end
