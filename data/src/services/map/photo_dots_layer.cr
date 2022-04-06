class Map::PhotoDotsLayer
  Log = ::Log.for(self)

  def initialize(
    photos,
    @tiles_layer : TilesLayer,
    @photo_direct_link : Bool = false,
    @dot_radius : Int32 = 5
  )
    @map_height = @tiles_layer.map_height.as(Int32)
    @map_width = @tiles_layer.map_width.as(Int32)

    @photos = photos.select { |pe| pe.exif && pe.exif.not_nil!.lat }.as(Array(PhotoEntity))

    Log.debug { "#{@photos.size} photos with latlong" }
  end

  def render_svg
    return String.build do |s|
      s << "<g id='photo-map-photos' >\n"

      i = 0_u64
      circle_size = @dot_radius

      # not used at this moment
      thumb_size = 10
      half_size = thumb_size / 2

      @photos.each_with_index do |photo_entity, i|
        s << photo_entity_to_svg_image(
          photo_entity: photo_entity,
          i: i,
          half_size: half_size,
          thumb_size: thumb_size,
          circle_size: circle_size
        )
      end

      s << "</g>\n"
    end
  end

  def select_photos_for_quant_and_add_to_list(
    x : Int32,
    y : Int32
  )
    lat1, lon1 = @tiles_layer.geo_coords_from_map_pixel_position(x, y)
    lat2, lon2 = @tiles_layer.geo_coords_from_map_pixel_position(x + @quant_size, y + @quant_size)

    selected_photos = select_photos_for_area(
      lat_min: lat2, # Y/lat axis is reversed
      lat_max: lat1,
      lon_min: lon1,
      lon_max: lon2,
    )

    # no photos, move along
    if selected_photos.size > 0
      Log.debug { "#{selected_photos.size} selected_photos x: #{x} y: #{y}" }

      # having array of photos take the best one
      # TODO: we need some logic to select which photos are better
      # even if they are not post published
      selected_photo = select_suitable_photo(selected_photos)

      if selected_photo
        @photo_map_sets << PhotoMapSet.new(
          pixel_x: x,
          pixel_y: y,
          photo: selected_photo.not_nil!
        )
      end
    end
  end

  # using min and max because it's compared math.
  # we ignore direction of growth
  def select_photos_for_area(
    lat_min : Float64,
    lat_max : Float64,
    lon_min : Float64,
    lon_max : Float64
  )
    @photos.select do |photo|
      photo_lat = photo.exif.not_nil!.lat.not_nil!
      photo_lon = photo.exif.not_nil!.lon.not_nil!

      photo_lat >= lat_min &&
        photo_lat < lat_max &&
        photo_lon >= lon_min &&
        photo_lon < lon_max
    end
  end

  def select_suitable_photo(array : Array(PhotoEntity)) : (PhotoEntity | Nil)
    return nil if array.size == 0

    selected = array.select { |photo| photo.is_map }
    # then PhotoEntity#is_timeline last
    if selected.size == 0
      selected = array.select { |photo| photo.is_timeline }
    end
    # TODO select published
    # require storing published flag in PhotoEntity
    if selected.size == 0
      selected = array
    end

    # sort by time ASC
    selected = selected.sort { |a, b| a.time <=> b.time }

    # and return latest one
    return selected.last
  end

  def photo_entity_to_color(photo_entity)
    day_of_year = photo_entity.exif.not_nil!.time.not_nil!.day_of_year
    phase = (day_of_year.to_f / 365.to_f) * 2.0 * Math::PI

    blue = 255.0 * ((Math.cos(phase) + 1.0) / 2.0)
    green = 255.0 * ((Math.sin(phase) + 1.0) / 2.0)
    # start 7 month -> about 200
    # peak 10 month -> about 270
    # stop -> about 320
    red = 0.0
    if day_of_year >= 150 && day_of_year < 350
      # custom calculation here
      # convert range 200-320 to 0-1
      red_phase = ((day_of_year - 150).to_f / (350.0 - 150.0)) * Math::PI
      red = 255.0 * (Math.sin(red_phase))
    end

    blue = 255.0 if blue > 255.0
    green = 255.0 if green > 255.0
    red = 255.0 if red > 255.0

    blue = 0.0 if blue < 0.0
    green = 0.0 if green < 0.0
    red = 0.0 if red < 0.0

    return "rgb(#{red.to_i},#{green.to_i},#{blue.to_i})"
  end

  def photo_entity_to_svg_image(
    photo_entity,
    i,
    half_size,
    thumb_size,
    circle_size
  )
    thumb_url = photo_entity.map_thumb_image_src
    photo_url = photo_entity.full_image_src

    x, y = @tiles_layer.in_map_position_from_geo_coords(
      lat_deg: photo_entity.exif.not_nil!.lat.not_nil!,
      lon_deg: photo_entity.exif.not_nil!.lon.not_nil!
    ).as(Tuple(Int32, Int32))

    # for cropping
    @tiles_layer.mark_top_left_corner(x.to_i, y.to_i)
    @tiles_layer.mark_bottom_right_corner(x.to_i, y.to_i)

    return String.build do |s|
      s << "<a href='#{photo_url}' target='_blank'>\n"
      s << svg_dot(
        x: x,
        y: y,
        circle_size: circle_size,
        color: photo_entity_to_color(photo_entity)
      )
      s << "</a>\n"
    end

    # XXX: that not work as intended
    # return String.build do |s|
    #   id_name = "image_#{i}"
    #
    #   s << "<svg x='#{x.to_i - half_size}' y='#{y.to_i - half_size}' width='#{thumb_size}' height='#{thumb_size}' class='photo-map-cirle-photo'>\n"
    #
    #   s << "<defs>\n"
    #   s << "  <pattern id=\"#{id_name}\" patternUnits=\"userSpaceOnUse\" height=\"#{thumb_size}\" width=\"#{thumb_size}\">\n"
    #   s << "    <image x=\"0\" y=\"0\" height=\"#{thumb_size}\" width=\"#{thumb_size}\" xlink:href=\"#{thumb_url}\"></image>\n"
    #   s << "  </pattern>\n"
    #   s << "</defs>\n"
    #
    #   s << "<a href='#{photo_url}' target='_blank'>\n"
    #   s << "<circle id='#{id_name}' cx=\"#{half_size}\" cy=\"#{half_size}\" r=\"#{circle_size}\" fill=\"url(##{id_name})\"/>\n"
    #   s << "</a>\n"
    #
    #   s << "</svg>\n"
    # end
  end

  def svg_dot(
    x,
    y,
    circle_size,
    color
  )
    return svg_rounded_square(
      x,
      y,
      circle_size,
      color,
      corner_round = 3
    )
  end

  def svg_circle(
    x,
    y,
    circle_size,
    color
  )
    return "  <circle cx=\"#{x}\" cy=\"#{y}\" r=\"#{circle_size}\" fill='#{color}' style='stroke:rgb(0,0,0);stroke-width:1' />\n"
  end

  def svg_rounded_square(
    x,
    y,
    circle_size,
    color,
    corner_round = 3
  )
    return "  <rect x=\"#{x - (circle_size / 2)}\" y=\"#{y - (circle_size / 2)}\" width=\"#{circle_size}\" height=\"#{circle_size}\" rx=\"#{corner_round}\" fill='#{color}' style='stroke:rgb(0,0,0);stroke-width:1' />\n"
  end
end
