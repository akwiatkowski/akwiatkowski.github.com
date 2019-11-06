require "./models/town_entity"
require "./models/tag_entity"
require "./models/land_type_entity"
require "./models/land_entity"
require "./models/transport_poi_entity"
require "./models/todo_route_entity"

require "./services/exif_processor"

class Tremolite::DataManager
  CACHE_PATH = "cache"

  def custom_initialize
    @towns = Array(TownEntity).new
    @town_slugs = Array(String).new
    @voivodeships = Array(TownEntity).new
    @tags = Array(TagEntity).new
    @land_types = Array(LandTypeEntity).new
    @lands = Array(LandEntity).new
    @transport_pois = Array(TransportPoiEntity).new
    @todo_routes = Array(TodoRouteEntity).new
    @photos = Array(PhotoEntity).new
    @exifs = Array(ExifEntity).new

    @cache_path = CACHE_PATH
  end

  getter :tags
  getter :towns, :town_slugs, :voivodeships
  getter :land_types, :lands, :todo_routes, :transport_pois, :post_image_entities
  getter :photos, :exifs

  def custom_load
    load_towns
    load_tags
    load_land_types
    load_lands
    load_transport_pois
    load_todo_routes
    load_exif_entities
  end

  def load_towns
    Dir[File.join([@data_path, "towns", "**", "*"])].each do |f|
      if File.file?(f)
        load_town_yaml(f)
      end
    end
  end

  def load_tags
    f = File.join([@data_path, "tags.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TagEntity.new(tag)
      @tags.not_nil! << o
    end
  end

  def load_land_types
    f = File.join([@data_path, "land_types.yml"])
    YAML.parse(File.read(f)).as_a.each do |land_type|
      o = LandTypeEntity.new(land_type)
      @land_types.not_nil! << o
    end
  end

  def load_lands
    f = File.join([@data_path, "lands.yml"])
    YAML.parse(File.read(f)).as_a.each do |land|
      o = LandEntity.new(land)
      @lands.not_nil! << o
    end
  end

  def load_transport_pois
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
    f = File.join([@data_path, "todo_routes.yml"])
    YAML.parse(File.read(f)).as_a.each do |tag|
      o = TodoRouteEntity.new(y: tag, transport_pois: @transport_pois.not_nil!, logger: @logger)
      @todo_routes.not_nil! << o
    end
  end

  def load_exif_entities
    path = File.join([@cache_path, "exifs.yml"])
    return unless File.exists?(path)

    @exifs = Array(ExifEntity).from_yaml(File.open(path))
  end

  def save_exif_entities
    path = File.join([@cache_path, "exifs.yml"])
    File.open(path, "w") do |f|
      @exifs.to_yaml(f)
    end

    @logger.info("#{self.class}: save_exif_entities #{@blog.data_manager.not_nil!.exifs.not_nil!.size}")
  end

  # search in @exifs, match and assign or generate
  def process_photo_entity(photo_entity : PhotoEntity)
    selected = @exifs.not_nil!.select do |e|
      e.post_slug == photo_entity.post_slug &&
      e.image_filename == photo_entity.image_filename
    end

    if selected.size == 0
      exif = ExifProcessor.process(
        photo_entity: photo_entity,
        path: @blog.data_path.as(String)
      )

      @exifs.not_nil! << exif

      # periodically save exifs
      if @exifs.not_nil!.size % 500 == 0
        save_exif_entities
      end
    else
      exif = selected.first
    end

    photo_entity.exif = exif

    @photos.not_nil! << photo_entity

    return photo_entity
  end

  private def load_town_yaml(f)
    town_yaml = YAML.parse(File.read(f))
    town_yaml.as_a.each do |town|
      o = TownEntity.new(town)
      if o.is_town?
        @towns.not_nil! << o
        @town_slugs.not_nil! << o.slug
      end
      if o.is_voivodeship?
        @voivodeships.not_nil! << o
      end
    end

    @towns = @towns.not_nil!.sort { |a, b| a.slug <=> b.slug }.uniq { |a| a.slug }
    @town_slugs = @town_slugs.not_nil!.sort.uniq
    @voivodeships = @voivodeships.not_nil!.sort { |a, b| a.slug <=> b.slug }.uniq { |a| a.slug }
  end
end
