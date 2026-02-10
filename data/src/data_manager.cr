require "./models/all"

require "./services/nav_stats_cache"
require "./services/exif_processor"
require "./services/preloaded_post_referenced_links"
require "./services/photo_coord_quant_cache"
require "./services/area_data_loader"
require "./services/area_photo_selector"
require "./services/photo_analysis_cache"

require "./data_manager/exif_db"
require "./data_manager/photo_map_dictionary"

class Tremolite::DataManager
  include Profiled

  def initialize(
    @config_path : String,
    @data_path : String = "",
    @cache_path : String = "",
    @output_path : String = "",
    @posts_path : String = "",
    @posts_ext : String = "",
    @html_buffer : Tremolite::HtmlBuffer = Tremolite::HtmlBuffer.new,
  )
    @config_path = @data_path if @config_path.to_s == ""
    @config_hash = Hash(String, String).new

    Log.debug { "START" }

    # Entity arrays
    @tags = Array(TagEntity).new
    @photo_tags = Array(PhotoTagEntity).new
    @train_stations = Array(TrainStationEntity).new
    @ideas = Array(IdeaEntity).new

    # Services
    @area_data_loader = AreaDataLoader.new(
      config_path: @config_path,
      cache_path: @cache_path
    )
    Profiler.measure("yaml", "areas") { @area_data_loader.not_nil!.load_areas }

    @post_coord_quant_cache = PostCoordQuantCache.new(
      cache_path: @cache_path
    )
    @photo_coord_quant_cache = PhotoCoordQuantCache.new(
      cache_path: @cache_path,
      all_towns: @area_data_loader.not_nil!.areas_of_type(AreaType::Town)
    )
    @nav_stats_cache = NavStatsCache.new(
      cache_path: @cache_path
    )
    @exif_db = ExifDb.new(
      cache_path: @cache_path,
      data_path: @data_path,
      photo_tags: @photo_tags.not_nil!
    )
    @photo_analysis_cache = PhotoAnalysisCache.new(
      cache_path: @cache_path,
      data_path: @data_path
    )
    @photo_map_dictionary = PhotoMapDictionary.new(
      output_path: @output_path
    )

    # Load config and entity data
    load_config
    load_tags
    load_train_stations
    load_ideas
    load_photo_tags

    init_preloaded_post_referenced_links

    Log.debug { "INITIALIZED" }
  end

  def init_preloaded_post_referenced_links
    @preloaded_post_referenced_links = PreloadedPostReferencedLinks.new(
      html_buffer: @html_buffer,
      posts_path: @posts_path,
      posts_ext: @posts_ext
    )
  end

  getter :tags
  getter :ideas, :photo_tags, :train_stations

  getter :nav_stats_cache, :post_coord_quant_cache, :photo_coord_quant_cache
  getter :photo_map_dictionary
  getter :area_data_loader

  def exif_db
    return @exif_db.not_nil!
  end

  def photo_analysis_cache
    return @photo_analysis_cache.not_nil!
  end

  def preloaded_post_referenced_links
    return @preloaded_post_referenced_links.not_nil!
  end

  # end of getters

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

end
