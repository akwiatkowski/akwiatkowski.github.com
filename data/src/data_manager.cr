require "./models/all"

require "./services/nav_stats_cache"
require "./services/exif_processor"
require "./services/preloaded_post_referenced_links"
require "./services/photo_coord_quant_cache"
require "./services/area_data_loader"
require "./services/area_photo_selector"

require "./data_manager/exif_db"
require "./data_manager/photo_map_dictionary"

class Tremolite::DataManager
  def custom_initialize
    @towns = Array(TownEntity).new
    @town_slugs = Array(String).new
    @voivodeships = Array(VoivodeshipEntity).new
    @tags = Array(TagEntity).new
    @photo_tags = Array(PhotoTagEntity).new
    # @land_types = Array(LandTypeEntity).new
    @lands = Array(LandEntity).new
    @portfolios = Array(PortfolioEntity).new
    @train_stations = Array(TrainStationEntity).new
    @ideas = Array(IdeaEntity).new

    # PHASE6_DEPRECATED: TownPhotoCache replaced by AreaPhotoSelector
    # @town_photo_cache = TownPhotoCache.new(
    #   blog: @blog
    # )
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
    @area_data_loader = AreaDataLoader.new(
      config_path: @config_path,
      cache_path: @blog.cache_path
    )
    @area_data_loader.not_nil!.load_areas
  end

  getter :tags
  getter :towns, :town_slugs, :voivodeships
  getter :lands, :post_image_entities, :portfolios
  getter :ideas, :photo_tags, :train_stations

  # PHASE6_DEPRECATED: getter :town_photo_cache - replaced by AreaPhotoSelector
  getter :nav_stats_cache, :post_coord_quant_cache, :photo_coord_quant_cache
  getter :photo_map_dictionary
  getter :area_data_loader

  def exif_db
    return @exif_db.not_nil!
  end

  def preloaded_post_referenced_links
    return @preloaded_post_referenced_links.not_nil!
  end

  # end of getters

  def custom_load
    load_lands # lands are needed before towns
    load_towns
    load_tags
    load_portfolio
    load_train_stations
    load_ideas
    load_photo_tags
  end

  def load_train_stations
    Log.debug { "loading train stations" }

    f = File.join([@config_path, "train_stations.yml"])
    YAML.parse(File.read(f)).as_a.each do |train_station|
      o = TrainStationEntity.new(train_station)
      @train_stations.not_nil! << o
    end
  end

  def load_ideas
    Log.debug { "loading ideas" }

    ideas_path = File.join([@data_path, "ideas"])
    ideas_scan_path = File.join([ideas_path, "*.yaml"])
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

  def load_towns # TODO: is it needed or deprecated?
    Log.debug { "loading towns" }

    Dir[File.join([@config_path, "towns", "**", "*"])].each do |f|
      if File.file?(f)
        load_town_yaml(f)
      end
    end
  end

  # DEPRECATED: Use visited_town_slugs_selfpropelled or visited_town_areas_selfpropelled
  # self-propelled
  def towns_already_visited_only_selfpropelled
    slugs = Array(String).new
    @blog.post_collection.posts.each do |post|
      next if post.towns.nil?

      slugs += post.towns.not_nil!
      slugs.uniq.sort
    end

    return @towns.not_nil!.select do |town_entity|
      slugs.includes?(town_entity.slug)
    end
  end

  # Get slugs of towns visited in self-propelled trips
  def visited_town_slugs_selfpropelled : Array(String)
    slugs = Set(String).new
    @blog.post_collection.posts.each do |post|
      next unless post.self_propelled?
      next if post.towns.nil?
      post.towns.not_nil!.each { |slug| slugs << slug }
    end
    slugs.to_a.sort
  end

  # Get AreaEntity towns that have been visited in self-propelled trips
  def visited_town_areas_selfpropelled : Array(AreaEntity)
    slugs = visited_town_slugs_selfpropelled
    @area_data_loader.not_nil!.areas_of_type(AreaType::Town).select do |area|
      slugs.includes?(area.slug)
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

  def tag_by_slug(slug : String)
    selected_tags = @tags.not_nil!.select do |tag|
      tag.slug == slug
    end

    return selected_tags[0]?
  end

  private def load_town_yaml(f)
    town_yaml = YAML.parse(File.read(f))
    town_yaml.as_a.each do |town|
      o = TownEntity.new(town: town, lands: @lands.not_nil!)
      @towns.not_nil! << o
      @town_slugs.not_nil! << o.slug
    end

    @towns = @towns.not_nil!.sort { |a, b| a.slug <=> b.slug }.uniq { |a| a.slug }
    @town_slugs = @town_slugs.not_nil!.sort.uniq
  end
end
