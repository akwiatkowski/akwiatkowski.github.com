require "./models/town_entity"
require "./models/voivodeship_entity"
require "./models/tag_entity"
require "./models/land_type_entity"
require "./models/land_entity"
require "./models/transport_poi_entity"
require "./models/todo_route_entity"
require "./models/portfolio_entity"

require "./services/exif_processor"
require "./data_manager/exif_db"

class Tremolite::DataManager
  CACHE_PATH = "cache"

  def custom_initialize
    @towns = Array(TownEntity).new
    @town_slugs = Array(String).new
    @voivodeships = Array(VoivodeshipEntity).new
    @tags = Array(TagEntity).new
    @land_types = Array(LandTypeEntity).new
    @lands = Array(LandEntity).new
    @transport_pois = Array(TransportPoiEntity).new
    @todo_routes = Array(TodoRouteEntity).new
    @portfolios = Array(PortfolioEntity).new
    @town_photo_cache = TownPhotoCache.new(@blog)

    @exif_db = ExifDb.new(
      blog: @blog
    )
  end

  getter :tags
  getter :towns, :town_slugs, :voivodeships
  getter :land_types, :lands, :todo_routes, :transport_pois, :post_image_entities, :portfolios
  getter :town_photo_cache

  def exif_db
    return @exif_db.not_nil!
  end

  # end of getters

  def custom_load
    load_towns
    load_tags
    load_land_types
    load_lands
    load_transport_pois
    load_todo_routes
    load_portfolio
  end

  def load_portfolio
    Log.debug { "loading portfolio" }

    f = File.join([@data_path, "portfolio.yml"])
    YAML.parse(File.read(f)).as_a.each do |portfolio|
      o = PortfolioEntity.new(portfolio)
      @portfolios.not_nil! << o
    end
  end

  def load_towns
    Log.debug { "loading towns" }

    Dir[File.join([@data_path, "towns", "**", "*"])].each do |f|
      if File.file?(f)
        load_town_yaml(f)
      end
    end
  end

  def load_tags
    Log.debug { "loading tags" }

    f = File.join([@data_path, "tags.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TagEntity.new(tag)
      @tags.not_nil! << o
    end
  end

  def load_land_types
    Log.debug { "loading land types" }

    f = File.join([@data_path, "land_types.yml"])
    YAML.parse(File.read(f)).as_a.each do |land_type|
      o = LandTypeEntity.new(land_type)
      @land_types.not_nil! << o
    end
  end

  def load_lands
    Log.debug { "loading lands" }

    f = File.join([@data_path, "lands.yml"])
    YAML.parse(File.read(f)).as_a.each do |land|
      o = LandEntity.new(land)
      @lands.not_nil! << o
    end
  end

  def load_transport_pois
    Log.debug { "loading transport pois" }

    f = File.join([@data_path, "transport_pois.yml"])
    YAML.parse(File.read(f)).as_a.each do |transport_poi|
      o = TransportPoiEntity.new(transport_poi)
      @transport_pois.not_nil! << o
    end

    # setup closest
    @transport_pois.not_nil!.each do |transport_poi|
      transport_poi.assign_closest_major(@transport_pois.not_nil!)
    end
  end

  def load_todo_routes
    Log.debug { "loading todo routes" }

    f = File.join([@data_path, "todo_routes.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TodoRouteEntity.new(y: tag, transport_pois: @transport_pois.not_nil!)
      @todo_routes.not_nil! << o
    end
  end

  private def load_town_yaml(f)
    town_yaml = YAML.parse(File.read(f))
    town_yaml.as_a.each do |town|
      o = TownEntity.new(town)
      if town["type"].to_s != "voivodeship"
        @towns.not_nil! << o
        @town_slugs.not_nil! << o.slug
      elsif town["type"].to_s == "voivodeship"
        o = VoivodeshipEntity.new(town)
        @voivodeships.not_nil! << o
      end
    end

    @towns = @towns.not_nil!.sort { |a, b| a.slug <=> b.slug }.uniq { |a| a.slug }
    @town_slugs = @town_slugs.not_nil!.sort.uniq
    @voivodeships = @voivodeships.not_nil!.sort { |a, b| a.slug <=> b.slug }.uniq { |a| a.slug }
  end
end
