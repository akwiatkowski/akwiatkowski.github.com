require "logger"

require "./const"
require "./tiles_layer"

class Map::Downloader
  Log = ::Log.for(self)

  DEFAULT_ZOOM = 10
  PUBLIC_PATH  = "public/tiles"
  # download addition border tile
  BORDER_TILE = 2

  def initialize(
    @lat_from : Float64,
    @lat_to : Float64,
    @lon_from : Float64,
    @lon_to : Float64,
    @zoom = DEFAULT_ZOOM,
    @type = Map::MapTile::Ump,
    @show_command = false
  )
    x_from_float, y_from_float = TilesLayer.tile_coords_from_geo_coords(@lat_from, @lon_from, @zoom)
    x_to_float, y_to_float = TilesLayer.tile_coords_from_geo_coords(@lat_to, @lon_to, @zoom)

    @x_from = [
      x_from_float.floor.to_i,
      x_to_float.ceil.to_i,
    ].min.as(Int32)
    @x_from -= BORDER_TILE

    @x_to = [
      x_from_float.floor.to_i,
      x_to_float.ceil.to_i,
    ].max.as(Int32)
    @x_to += BORDER_TILE

    @y_from = [
      y_from_float.floor.to_i,
      y_to_float.ceil.to_i,
    ].min.as(Int32)
    @y_from -= BORDER_TILE

    @y_to = [
      y_from_float.floor.to_i,
      y_to_float.ceil.to_i,
    ].max.as(Int32)
    @y_to += BORDER_TILE
  end

  def make_it_so
    Log.info { "#{@x_to - @x_from}*#{@y_to - @y_from}=#{(@x_to - @x_from)*(@y_to - @y_from)} tiles to download" }

    (@x_from..@x_to).each do |x|
      # prepare parent path
      base_path = generate_base_path(x)
      Dir.mkdir_p(base_path)

      (@y_from..@y_to).each do |y|
        path = generate_path(x, y)
        if !File.exists?(path) || File.size(path) == 0
          download(x, y)
        end
      end
    end
  end

  def ump?
    @type == Map::MapTile::Ump
  end

  def download(x, y)
    command = generate_command(x, y)

    puts command if @show_command
    `#{command}`
  end

  def generate_url(x, y)
    if ump?
      "http://1.tiles.ump.waw.pl/ump_tiles/#{@zoom}/#{x}/#{y}.png"
    else
      ""
    end
  end

  def generate_base_path(x, y = nil)
    return File.join(
      [
        PUBLIC_PATH,
        @type.to_s.downcase,
        @zoom,
        x,
      ]
    )
  end

  def generate_path(x, y)
    return File.join([generate_base_path(x, y), "#{y}.png"])
  end

  def generate_command(x, y)
    if ump?
      cookie = nil
      command = "curl '#{generate_url(x, y)}' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.9,pl;q=0.8,cs;q=0.7' -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.89 Safari/537.36' -H 'Accept: image/webp,image/apng,image/*,*/*;q=0.8' -H 'Referer: http://mapa.ump.waw.pl/ump-www/' -H 'Cookie: #{cookie}' -H 'Connection: keep-alive' --compressed -o '#{generate_path(x, y)}'"
    else
      command = ""
    end

    return command
  end
end
