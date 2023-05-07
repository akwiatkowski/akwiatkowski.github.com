struct CoordQuant
  include YAML::Serializable

  DEFAULT_QUANT_RESOLUTION = 0.05

  @lat : Float32
  @lon : Float32

  def initialize(
    lat : (Float32 | Float64),
    lon : (Float32 | Float64),
    quant : (Float32 | Float64) = DEFAULT_QUANT_RESOLUTION
  )
    @lat = self.class.round(
      value: lat,
      quant: quant
    )
    @lon = self.class.round(
      value: lon,
      quant: quant
    )
  end

  def <=>(other)
    if self.lat == other.lat
      return self.lon <=> other.lon
    else
      return self.lat <=> other.lat
    end
  end

  def self.round(
    value : YAML::ParseContext | YAML::Nodes::Node,
    quant : (Float32 | Float64) = DEFAULT_QUANT_RESOLUTION
  )
    return round(value.to_s.to_f32)
  end

  def self.round(
    value : (Float32 | Float64),
    quant : (Float32 | Float64) = DEFAULT_QUANT_RESOLUTION
  )
    return ((value.to_f32 / quant).round.to_f * quant).to_f32
  end

  getter :lat, :lon
end

struct CoordSet
  @set : Array(CoordQuant)
  @quant : Float32

  # create from array of arrays
  def initialize(
    coords_array : Array(Array(Float64 | Float32)),
    quant : (Float32 | Float64) = CoordQuant::DEFAULT_QUANT_RESOLUTION.to_f32
  )
    set = Array(CoordQuant).new
    @quant = quant.to_f32

    coords_array.each do |coord_array|
      new_coord = CoordQuant.new(
        lat: coord_array[0],
        lon: coord_array[1],
        quant: @quant
      )
      set << new_coord unless set.includes?(new_coord)
    end

    @set = set.uniq.sort
  end

  # create from post: detailed_routes and photos
  def initialize(
    post : Tremolite::Post,
    quant : (Float32 | Float64) = CoordQuant::DEFAULT_QUANT_RESOLUTION.to_f32
  )
    @set = Array(CoordQuant).new
    @quant = quant.to_f32

    # route
    post.detailed_routes.map do |dr|
      dr.route.each do |coord_array|
        new_coord = CoordQuant.new(
          lat: coord_array[0],
          lon: coord_array[1],
          quant: @quant
        )
        @set << new_coord unless set.includes?(new_coord)
      end
    end

    # photos
    post.published_photo_entities.map do |photo_entity|
      next if photo_entity.exif.not_nil!.lat.nil? || photo_entity.exif.not_nil!.lon.nil?

      new_coord = CoordQuant.new(
        lat: photo_entity.exif.not_nil!.lat.not_nil!,
        lon: photo_entity.exif.not_nil!.lon.not_nil!,
        quant: @quant
      )
      @set << new_coord unless set.includes?(new_coord)
    end

    @set = @set.uniq.sort
  end

  def self.compare(post : Tremolite::Post, other_post : Tremolite::Post)
    raise NotImplementedError
  end

  def self.compare(set : Array(CoordQuant), other_set : Array(CoordQuant))
    common_size = (set & other_set).size
    set_size = set.size

    # divide by 0 fix
    set_size = 1 if set_size < 1

    return {
      common_factor:   (100.0 * common_size.to_f / set_size.to_f).to_i,
      common_size:     common_size,
      not_common_size: set_size - common_size,
    }
  end

  def compare(other : CoordSet)
    return self.class.compare(
      set: self.set,
      other_set: other.set
    )
  end

  getter :set
end
