require "logger"

class MapTilesDownloader
  DEFAULT_ZOOM = 10

  enum MapType
    Ump
    Osm
  end

  def initialize(
    @lat_from : Float64,
    @lat_to : Float64,
    @lon_from : Float64,
    @lon_to : Float64,
    @logger = Logger.new(STDOUT),
    @zoom = DEFAULT_ZOOM,
    @type = MapType::Ump
  )
    @x_from, @y_to = tile_numbers_from_coords(@lat_from, @lon_from).as(Tuple(Int32, Int32))
    @x_to, @y_from = tile_numbers_from_coords(@lat_to, @lon_to).as(Tuple(Int32, Int32))
  end

  getter :x_from, :y_to, :x_to, :y_from
  getter :zoom

  def generate_url(x, y)
    if @type == MapType::Ump
      "http://1.tiles.ump.waw.pl/ump_tiles/#{@zoom}/#{x}/#{y}.png"
    else
      ""
    end
  end

  PUBLIC_PATH = "public/tiles"

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

  def download(x, y)
    url = generate_url(x, y)
    path = generate_path(x, y)

    command = "wget #{url} -o #{path}"

    # temp command to download from ump
    if @type == MapType::Ump
      command = "curl '#{url}' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.9,pl;q=0.8,cs;q=0.7' -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.89 Safari/537.36' -H 'Accept: image/webp,image/apng,image/*,*/*;q=0.8' -H 'Referer: http://mapa.ump.waw.pl/ump-www/' -H 'Cookie: ump_trasy_cookie=lon%3D17.13593%26lat%3D52.55590%26zoom%3D11%26tstamp%3D1584809406234;ump_cookie=lon%3D14.93213%26lat%3D52.34827%26zoom%3D11%26layers%3DUMP%252540Mapnik%253Dtrue%2526OpenStreetMaps%253Dfalse%2526UMP%252520Hybryda%253Dfalse%2526Google%252520Ulice%253Dfalse%2526Google%252520Sat%253Dfalse%2526Google%252520Teren%253Dfalse%2526UMP%252540Mapnik-hybrid%253Dfalse%2526Warstwa%252520wektorowa%253Dtrue%2526Siatka%253Dfalse%2526OpenLayers.Handler.Path%253Dtrue%2526Bing%252520Ulice%253Dfalse%2526Bing%252520Sat%253Dfalse%2526G%252520StreetView%253Dfalse%2526Regiony%253Dfalse%2526punktyadresowe.pl%252520ulice%253Dfalse%2526punktyadresowe.pl%252520nmery%253Dfalse%2526punktyadresowe.pl%252520num%253Dfalse%2526Google%252520Hybrid%253Dfalse%2526Google%252520Sat%2525202%253Dfalse%2526punktyadresowe.pl%252520adresy%253Dfalse%26tstamp%3D1585078195566' -H 'Connection: keep-alive' --compressed -o '#{path}'"
    end

    puts command
    `#{command}`
  end

  def make_it_so
    @logger.info("#{@x_to - @x_from}*#{@y_to - @y_from}=#{(@x_to - @x_from)*(@y_to - @y_from)} tiles to download")

    (@x_from..@x_to).each do |x|
      # prepare parent path
      base_path = generate_base_path(x)
      Dir.mkdir_p(base_path)

      (@y_from..@y_to).each do |y|
        download(x, y)
      end
    end
  end

  def tile_numbers_from_coords(lat_deg, lng_deg, zoom = @zoom) : Tuple(Int32, Int32)
    lat_rad = lat_deg / 180.0 * Math::PI
    n = 2.0 ** zoom
    x = ((lng_deg + 180.0) / 360.0 * n).to_i
    y = ((1.0 - Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI) / 2.0 * n).to_i

    return x, y
  end

  def get_lat_lng_for_number(x, y, zoom = @zoom)
    n = 2.0 ** zoom
    lon_deg = x / n * 360.0 - 180.0
    lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * y / n)))
    lat_deg = 180.0 * (lat_rad / Math::PI)

    return lat_deg, lon_deg
  end
end
