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
  include Profiled

  def custom_initialize
    @tags = Array(TagEntity).new
    @photo_tags = Array(PhotoTagEntity).new
    @train_stations = Array(TrainStationEntity).new
    @ideas = Array(IdeaEntity).new

    @area_data_loader = AreaDataLoader.new(
      config_path: @config_path,
      cache_path: @blog.cache_path
    )
    Profiler.measure("yaml", "areas") { @area_data_loader.not_nil!.load_areas }

    @post_coord_quant_cache = PostCoordQuantCache.new(
      cache_path: @blog.cache_path
    )
    @photo_coord_quant_cache = PhotoCoordQuantCache.new(
      cache_path: @blog.cache_path,
      all_towns: @area_data_loader.not_nil!.areas_of_type(AreaType::Town)
    )
    @nav_stats_cache = NavStatsCache.new(
      blog: @blog
    )
    @preloaded_post_referenced_links = PreloadedPostReferencedLinks.new(
      html_buffer: @blog.html_buffer.as(Tremolite::HtmlBuffer),
      posts_path: @blog.posts_path,
      posts_ext: @blog.posts_ext
    )
    @exif_db = ExifDb.new(
      blog: @blog
    )
    @photo_map_dictionary = PhotoMapDictionary.new(
      output_path: @blog.output_path
    )
  end

  getter :tags
  getter :post_image_entities
  getter :ideas, :photo_tags, :train_stations

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

  @[Profile(category: "yaml")]
  def custom_load
    load_tags
    load_train_stations
    load_ideas
    load_photo_tags
  end

  @[Profile(category: "yaml")]
  def load_train_stations
    Log.debug { "loading train stations" }

    f = File.join([@config_path, "train_stations.yml"])
    YAML.parse(File.read(f)).as_a.each do |train_station|
      o = TrainStationEntity.new(train_station)
      @train_stations.not_nil! << o
    end
  end

  @[Profile(category: "yaml")]
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

  # Get slugs of towns visited in self-propelled trips
  def visited_town_slugs_selfpropelled : Array(String)
    slugs = Set(String).new
    @blog.post_collection.posts.each do |post|
      next unless post.self_propelled?
      post.town_slugs.each { |slug| slugs << slug }
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

  @[Profile(category: "yaml")]
  def load_tags
    Log.debug { "loading tags" }

    f = File.join([@config_path, "tags.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TagEntity.new(tag)
      @tags.not_nil! << o
    end
  end

  @[Profile(category: "yaml")]
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

end
