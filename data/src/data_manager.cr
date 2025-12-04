require "./models/all"

require "./services/nav_stats_cache"
require "./services/exif_processor"
require "./services/preloaded_post_referenced_links"
require "./services/photo_coord_quant_cache"

require "./data_manager/exif_db"
require "./data_manager/photo_map_dictionary"

class Tremolite::DataManager
  def custom_initialize
    @towns = Array(TownEntity).new
    @town_slugs = Array(String).new
    @voivodeships = Array(VoivodeshipEntity).new
    @tags = Array(TagEntity).new
    @photo_tags = Array(PhotoTagEntity).new
    @land_types = Array(LandTypeEntity).new
    @lands = Array(LandEntity).new
    @transport_pois = Array(TransportPoiEntity).new
    @todo_routes = Array(TodoRouteEntity).new
    @portfolios = Array(PortfolioEntity).new
    @ideas = Array(IdeaEntity).new

    @town_photo_cache = TownPhotoCache.new(
      blog: @blog
    )
    @post_coord_quant_cache = PostCoordQuantCache.new(
      blog: @blog
    )
    @photo_coord_quant_cache = PhotoCoordQuantCache.new(
      blog: @blog
    )
    @nav_stats_cache = NavStatsCache.new(
      blog: @blog
    )
    @preloaded_post_referenced_links = PreloadedPostReferencedLinks.new(
      blog: @blog
    )
    @exif_db = ExifDb.new(
      blog: @blog
    )
    @photo_map_dictionary = PhotoMapDictionary.new(
      output_path: @blog.output_path
    )
  end

  getter :tags
  getter :towns, :town_slugs, :voivodeships
  getter :land_types, :lands, :todo_routes, :transport_pois, :post_image_entities, :portfolios
  getter :ideas, :photo_tags

  getter :town_photo_cache, :nav_stats_cache, :post_coord_quant_cache, :photo_coord_quant_cache
  getter :photo_map_dictionary

  def exif_db
    return @exif_db.not_nil!
  end

  def preloaded_post_referenced_links
    return @preloaded_post_referenced_links.not_nil!
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
    load_ideas
    load_photo_tags
  end

  def load_ideas
    Log.debug { "loading ideas" }

    ideas_path = File.join([@data_path, "ideas"])
    ideas_scan_path = File.join([ideas_path, "*.yaml"])
    puts ideas_scan_path
    Dir[ideas_scan_path].each do |f|
      if File.file?(f)
        idea = YAML.parse(File.read(f))
        @ideas.not_nil! << IdeaEntity.new(idea)
      end
    end
  end

  def load_portfolio
    Log.debug { "loading portfolio" }

    f = File.join([@config_path, "portfolio.yml"])
    YAML.parse(File.read(f)).as_a.each do |portfolio|
      o = PortfolioEntity.new(portfolio)
      @portfolios.not_nil! << o
    end
  end

  def load_towns
    Log.debug { "loading towns" }

    Dir[File.join([@config_path, "towns", "**", "*"])].each do |f|
      if File.file?(f)
        load_town_yaml(f)
      end
    end
  end

  def load_tags
    Log.debug { "loading tags" }

    f = File.join([@config_path, "tags.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TagEntity.new(tag)
      @tags.not_nil! << o
    end
  end

  def load_land_types
    Log.debug { "loading land types" }

    f = File.join([@config_path, "land_types.yml"])
    YAML.parse(File.read(f)).as_a.each do |land_type|
      o = LandTypeEntity.new(land_type)
      @land_types.not_nil! << o
    end
  end

  def load_lands
    Log.debug { "loading lands" }

    f = File.join([@config_path, "lands.yml"])
    YAML.parse(File.read(f)).as_a.each do |land|
      o = LandEntity.new(land)
      @lands.not_nil! << o
    end
  end

  def load_photo_tags
    Log.debug { "loading photo tags" }

    f = File.join([@config_path, "photo_tags.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = PhotoTagEntity.new(tag)
      @photo_tags.not_nil! << o
    end
  end

  def load_transport_pois
    Log.debug { "loading transport pois" }

    f = File.join([@config_path, "transport_pois.yml"])
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

    f = File.join([@config_path, "todo_routes.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TodoRouteEntity.new(y: tag, transport_pois: @transport_pois.not_nil!)
      @todo_routes.not_nil! << o
    end
  end

  def tag_by_slug(slug : String)
    selected_tags = @tags.not_nil!.select do |tag|
      tag.slug == slug
    end

    return selected_tags[0]?
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
