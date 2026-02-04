require "yaml"

# ##############################################################################
# PHASE6_DEPRECATED - DO NOT REMOVE WITHOUT MIGRATING DEPENDENCIES
# ##############################################################################
#
# DEPRECATED: Use AreaEntity with AreaType::Town instead
#
# This class is deprecated and will be removed after full migration.
# See PLAN.md for migration status.
#
# Dependencies that need migration:
# - data/src/data_manager.cr (loads towns)
# - data/src/validator.cr (validates town slugs)
# - data/src/post/initializers.cr (lands_from_towns)
# - data/src/services/photo_coord_quant_cache.cr (uses towns)
# - data/src/views/post_view/article_view.cr (renders town links)
#
# ##############################################################################

alias TownEntityHash = Hash(String, String | Array(String))

struct TownEntity
  Log = ::Log.for(self)

  MIN_LAND_COVERAGE_PERCENT_TO_ASSIGN = 30.0

  @slug : String
  @name : String
  @type : String

  @voivodeship : String?
  @lat : Float64?
  @lon : Float64?

  @lands : Array(LandEntity)

  getter :name, :slug, :voivodeship, :lat, :lon, :lands, :lands_percentage

  def initialize(town : YAML::Any, lands : Array(LandEntity))
    @slug = town["slug"].to_s
    @name = town["name"].to_s
    @type = town["type"].to_s
    @voivodeship = town["voivodeship"].as_s if town["voivodeship"]?
    @lat = town["lat"].to_s.to_f if town["lat"]?
    @lon = town["lon"].to_s.to_f if town["lon"]?

    @lands_percentage = Hash(String, Float64).new
    @lands = Array(LandEntity).new

    if town["lands"]?
      town["lands"].as_h.keys.each do |land_slug|
        land = lands.select { |land_iterated| land_iterated.slug == land_slug.as_s }.first

        percentage = town["lands"].as_h[land_slug].as_f
        @lands_percentage[land_slug.as_s] = percentage

        @lands << land if percentage >= MIN_LAND_COVERAGE_PERCENT_TO_ASSIGN
      end
    end
  end

  def to_hash
    h = TownEntityHash.new
    h["slug"] = @slug.to_s unless @slug.nil?
    h["name"] = @name.to_s unless @name.nil?
    h["type"] = @type.to_s unless @type.nil?
    h["voivodeship"] = @voivodeship.to_s unless @voivodeship.nil?

    return h
  end

  def is_town?
    return @type == "town"
  end

  def is_voivodeship?
    return @type == "voivodeship"
  end

  def view_url
    return "/gmina/#{@slug}.html"
  end

  def image_url
    File.join(["/", relative_image_url])
  end

  def relative_image_url
    File.join(["images", "town", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.towns.not_nil!.includes?(@slug)
  end

  def distance_to_coord(other_lat, other_lon)
    return Math.sqrt(
      ((@lat.not_nil!.to_f32 - other_lat.to_f32) ** 2) +
      ((@lon.not_nil!.to_f32 - other_lon.to_f32) ** 2)
    )
  end
end
