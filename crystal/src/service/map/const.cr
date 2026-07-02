module Map
  class DataError < Exception
  end

  enum MapTile
    Ump
    Osm
  end

  enum MapType
    # render just tiles
    Blank
    # divide map and try to find photo for every cell
    PhotoGrid
    # just render every photo as dot/small circle
    PhotoDots
    # draw route and add assigned photos located outside of route polyline
    PhotosAssignedToRoute
  end

  enum MapRoutesType
    # not render routes
    None
    # display all routes in 0 time
    Static
    # display next routes poly line after some seconds after previous one
    Animated
  end

  enum MapPhotoLinkTo
    # when you click on photo it points to just JPG file
    # TODO: in future maybe some kind of photo page + details
    LinkToPhoto
    # when you click on photo it points to post page
    LinkToPost
  end

  # when preparing range of map we need to decide if routes will be used
  # or photos or both, or maybe constant range
  enum CoordCropType
    # static
    WholePoland
    # dynamic
    PhotoCrop
    RouteCrop
    PhotoAndRouteCrop
  end

  TILE_WIDTH         = 256
  DEFAULT_ZOOM       =  10
  DEFAULT_PHOTO_SIZE = 200

  DEFAULT_DOT_RADIUS = 8

  DEFAULT_OVERALL_ZOOM       =  10
  DEFAULT_OVERALL_PHOTO_SIZE = 200

  DEFAULT_COARSE_ZOOM       =   8
  DEFAULT_COARSE_PHOTO_SIZE = 160

  # TODO maybe dowload 11 later?
  DEFAULT_DETAILED_ZOOM       = 10
  DEFAULT_DETAILED_PHOTO_SIZE = 50

  DEFAULT_SMALL_ZOOM       =   8
  DEFAULT_SMALL_PHOTO_SIZE = 100

  DEFAULT_SMALL_DETAILED_ZOOM       =  8
  DEFAULT_SMALL_DETAILED_PHOTO_SIZE = 25

  DEFAULT_VOIVODESHIP_ZOOM       =  10
  DEFAULT_VOIVODESHIP_PHOTO_SIZE = 100

  DEFAULT_VOIVODESHIP_SMALL_ZOOM       =  9
  DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE = 80

  DEFAULT_TAG_ZOOM       =  8
  DEFAULT_TAG_PHOTO_SIZE = 80

  VALID_ZOOMS             = [6, 7, 8, 9, 10, 11, 12, 13, 14, 16]
  DEFAULT_POST_PHOTO_SIZE = 120
end
