require "./const"

struct Map::MapConfig
  getter tile : MapTile
  getter type : MapType
  getter zoom : Int32
  getter photo_size : Int32
  getter render_routes : Bool
  getter routes_type : MapRoutesType
  getter photo_link_to : MapPhotoLinkTo
  getter dot_radius : Int32
  getter coord_crop_type : CoordCropType
  getter custom_width : Int32?
  getter custom_height : Int32?
  getter autozoom_width : Int32?
  getter fixed_coord_range : CoordRange?

  def initialize(
    @tile = MapTile::Ump,
    @type = MapType::Blank,
    @zoom = DEFAULT_ZOOM,
    @photo_size = DEFAULT_PHOTO_SIZE,
    @render_routes = true,
    @routes_type = MapRoutesType::Static,
    @photo_link_to = MapPhotoLinkTo::LinkToPost,
    @dot_radius = DEFAULT_DOT_RADIUS,
    @coord_crop_type = CoordCropType::PhotoAndRouteCrop,
    @custom_width = nil,
    @custom_height = nil,
    @autozoom_width = nil,
    @fixed_coord_range = nil,
  )
  end

  # Single post route map (strava-like)
  def self.post_route(zoom : Int32, custom_width : Int32 = 730)
    new(
      type: MapType::PhotoDots,
      photo_link_to: MapPhotoLinkTo::LinkToPhoto,
      coord_crop_type: CoordCropType::RouteCrop,
      routes_type: MapRoutesType::Static,
      zoom: zoom,
      custom_width: custom_width,
    )
  end

  # Single post big map with photos assigned to route
  def self.post_big(zoom : Int32)
    new(
      type: MapType::PhotosAssignedToRoute,
      photo_link_to: MapPhotoLinkTo::LinkToPhoto,
      coord_crop_type: CoordCropType::RouteCrop,
      routes_type: MapRoutesType::Static,
      zoom: zoom,
    )
  end

  # Global grid map (no routes)
  def self.global_grid(zoom : Int32, photo_size : Int32)
    new(
      type: MapType::PhotoGrid,
      photo_link_to: MapPhotoLinkTo::LinkToPost,
      routes_type: MapRoutesType::None,
      zoom: zoom,
      photo_size: photo_size,
    )
  end

  # Global dots map (no routes)
  def self.global_dots(zoom : Int32, dot_radius : Int32 = DEFAULT_DOT_RADIUS)
    new(
      type: MapType::PhotoDots,
      photo_link_to: MapPhotoLinkTo::LinkToPhoto,
      routes_type: MapRoutesType::None,
      zoom: zoom,
      dot_radius: dot_radius,
    )
  end

  # Global grid + routes
  def self.global_grid_and_routes(zoom : Int32, photo_size : Int32)
    new(
      type: MapType::PhotoGrid,
      photo_link_to: MapPhotoLinkTo::LinkToPost,
      routes_type: MapRoutesType::Static,
      zoom: zoom,
      photo_size: photo_size,
    )
  end

  # Global animated routes (no photos)
  def self.global_animated(zoom : Int32)
    new(
      type: MapType::Blank,
      routes_type: MapRoutesType::Animated,
      zoom: zoom,
    )
  end

  # Idea route map (routes only, autozoom)
  def self.idea_route(autozoom_width : Int32 = 700)
    new(
      type: MapType::Blank,
      routes_type: MapRoutesType::Static,
      autozoom_width: autozoom_width,
      zoom: 9,
    )
  end

  # Area/voivodeship map (filtered posts + routes)
  def self.area_grid(zoom : Int32, photo_size : Int32, fixed_coord_range : CoordRange? = nil)
    new(
      type: MapType::PhotoGrid,
      photo_link_to: MapPhotoLinkTo::LinkToPost,
      routes_type: MapRoutesType::Static,
      zoom: zoom,
      photo_size: photo_size,
      fixed_coord_range: fixed_coord_range,
    )
  end

  # Tagged photo map (grid, no routes)
  def self.tag_grid(zoom : Int32, photo_size : Int32)
    new(
      type: MapType::PhotoGrid,
      photo_link_to: MapPhotoLinkTo::LinkToPhoto,
      routes_type: MapRoutesType::None,
      zoom: zoom,
      photo_size: photo_size,
    )
  end
end
