require "./const"

struct Map::TileInfo
  getter pixel_x : Int32
  getter pixel_y : Int32
  getter url : String

  def initialize(@pixel_x, @pixel_y, @url)
  end
end

struct Map::RoutePolyline
  getter points : Array(Tuple(Int32, Int32))
  getter color_rgb : String
  getter animated : Bool

  def initialize(@points, @color_rgb, @animated = false)
  end
end

struct Map::DotElement
  getter x : Int32
  getter y : Int32
  getter color : String
  getter photo_url : String

  def initialize(@x, @y, @color, @photo_url)
  end
end

struct Map::GridPhotoElement
  getter x : Int32
  getter y : Int32
  getter size : Int32
  getter image_src : String
  getter link_url : String

  def initialize(@x, @y, @size, @image_src, @link_url)
  end
end

struct Map::AssignedPhotoElement
  getter point_x : Int32
  getter point_y : Int32
  getter corner_x : Int32
  getter corner_y : Int32
  getter center_x : Int32
  getter center_y : Int32
  getter image_size : Int32
  getter image_src : String
  getter href_url : String

  def initialize(@point_x, @point_y, @corner_x, @corner_y, @center_x, @center_y, @image_size, @image_src, @href_url)
  end
end

alias Map::PhotoElement = Map::DotElement | Map::GridPhotoElement | Map::AssignedPhotoElement

struct Map::ViewBox
  getter x : Int32
  getter y : Int32
  getter width : Int32
  getter height : Int32

  def initialize(@x, @y, @width, @height)
  end
end

class Map::MapResult
  getter tiles : Array(TileInfo)
  getter tile_source : MapTile
  getter route_polylines : Array(RoutePolyline)
  getter photo_elements : Array(PhotoElement)
  getter view_box : ViewBox
  getter map_width : Int32
  getter map_height : Int32
  getter center_lat : Float64
  getter center_lon : Float64
  getter zoom : Int32
  getter custom_width : Int32?
  getter custom_height : Int32?
  getter debug : Hash(String, String)

  def initialize(
    @tiles,
    @tile_source,
    @route_polylines,
    @photo_elements,
    @view_box,
    @map_width,
    @map_height,
    @center_lat,
    @center_lon,
    @zoom,
    @custom_width = nil,
    @custom_height = nil,
    @debug = Hash(String, String).new,
  )
  end
end
