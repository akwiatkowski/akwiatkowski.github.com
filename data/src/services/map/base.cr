require "yaml"

require "../../models/photo_entity"
require "../../models/coord_range"

require "./main"
require "./const"
require "./tiles_layer"
require "./routes_layer"
require "./crop"

require "./photo_layer/all"

class Map::Base
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @tile = Map::MapTile::Ump,
    @type = MapType::Blank,
    @zoom = DEFAULT_ZOOM,

    @post_slugs : Array(String) = Array(String).new,

    @photo_size = Map::DEFAULT_PHOTO_SIZE,
    @photo_entities : Array(PhotoEntity) = Array(PhotoEntity),

    # selective rendering
    @render_routes : Bool = true,

    @routes_type : Map::MapRoutesType = Map::MapRoutesType::Static,

    # by default photos are linked to Post not full src of PhotoEntity
    @photo_link_to : Map::MapPhotoLinkTo = Map::MapPhotoLinkTo::LinkToPost,

    # TODO: check how it works
    @todo_do_not_crop_routes : Bool = false,

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
    @internal_coord_range = CoordRange.new

    # if list of post slugs were provided select only for this posts
    if @post_slugs.size > 0
      all_photos = @photo_entities.select do |photo_entity|
        @post_slugs.includes?(photo_entity.post_slug)
      end
    else
      all_photos = @photo_entities
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

        if !@internal_coord_range.valid? || @todo_do_not_crop_routes
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
    @instance = Main.new(
      posts: @posts,
      photos: @photo_entities,

      tile: @tile,
      type: @type,
      zoom: @zoom,
      photo_size: @photo_size,

      render_routes: @render_routes,
      routes_type: @routes_type,

      photo_link_to: @photo_link_to,

      dot_radius: @dot_radius,
      coord_range: @coord_range,

      custom_width: @custom_width,
      custom_height: @custom_height,
    )
  end

  def to_svg
    @instance.to_svg
  end
end
