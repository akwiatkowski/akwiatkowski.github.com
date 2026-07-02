require "../models/area_type"
require "../models/area_entity"
require "../models/area_association"
require "../services/area_data_loader"

# Area-related extensions for Post class
# Provides memoized access to AreaEntity objects and calculated area associations
class Tremolite::Post
  # Memoized area entities by type
  @_area_entities : Hash(AreaType, Array(AreaEntity))?

  # Memoized calculated area associations (from areas_for_post cache)
  @_area_associations : Hash(AreaType, Array(AreaAssociation))?

  # Memoized foreign (external) area entities
  @_foreign_entities : Array(AreaEntity)?

  # Area data loader reference (set during post processing)
  @_area_data_loader : AreaDataLoader?

  # Set the area data loader (called during blog initialization)
  def area_data_loader=(loader : AreaDataLoader)
    @_area_data_loader = loader
  end

  # Get area entities of a specific type
  # Returns entities for areas this post is associated with (manual + calculated)
  def area_entities(type : AreaType) : Array(AreaEntity)
    load_area_entities unless @_area_entities
    @_area_entities.not_nil![type]? || [] of AreaEntity
  end

  # Convenience accessors for each area type
  def town_entities : Array(AreaEntity)
    area_entities(AreaType::Town)
  end

  def county_entities : Array(AreaEntity)
    area_entities(AreaType::County)
  end

  def voivodeship_entities : Array(AreaEntity)
    area_entities(AreaType::Voivodeship)
  end

  def meso_region_entities : Array(AreaEntity)
    area_entities(AreaType::MesoRegion)
  end

  def macro_region_entities : Array(AreaEntity)
    area_entities(AreaType::MacroRegion)
  end

  # Get foreign (external) area slugs from post YAML
  def foreign_slugs : Array(String)
    @foreign_slugs
  end

  # Get foreign (external) area entities
  # Returns AreaEntity objects for external areas referenced in the post
  def foreign_entities : Array(AreaEntity)
    load_foreign_entities unless @_foreign_entities
    @_foreign_entities.not_nil!
  end

  # Get calculated area associations (with distance data) for a specific type
  def area_associations(type : AreaType) : Array(AreaAssociation)
    load_area_associations unless @_area_associations
    @_area_associations.not_nil![type]? || [] of AreaAssociation
  end

  # Get all area slugs for a type (combined manual + calculated)
  def area_slugs(type : AreaType) : Array(String)
    slugs = Set(String).new

    # Add manual slugs (from post YAML headers)
    case type
    when AreaType::Town
      @town_slugs.each { |s| slugs << s }
    when AreaType::MesoRegion
      @land_slugs.each { |s| slugs << s }
    when AreaType::Voivodeship
      # voivodeships are mixed with towns in current implementation
      @town_slugs.each { |s| slugs << s }
    end

    # Add calculated slugs (from areas_for_post cache)
    area_associations(type).each { |a| slugs << a.slug }

    slugs.to_a
  end

  # Check if post was in a specific area
  def was_in_area?(area : AreaEntity) : Bool
    area_slugs(area.area_type).includes?(area.slug)
  end

  # Check if post was in area by type and slug
  def was_in_area?(type : AreaType, slug : String) : Bool
    area_slugs(type).includes?(slug)
  end

  private def load_area_entities
    @_area_entities = {} of AreaType => Array(AreaEntity)

    loader = @_area_data_loader
    return unless loader

    AreaType.each do |type|
      slugs = area_slugs(type)
      entities = slugs.compact_map { |slug| loader.area_by_slug(type, slug) }
      @_area_entities.not_nil![type] = entities
    end
  end

  private def load_area_associations
    @_area_associations = {} of AreaType => Array(AreaAssociation)

    loader = @_area_data_loader
    return unless loader

    @_area_associations = loader.load_for_post(self.slug)
  end

  private def load_foreign_entities
    @_foreign_entities = [] of AreaEntity

    loader = @_area_data_loader
    return unless loader

    foreign_slugs.each do |slug|
      entity = loader.external_area_by_slug(slug)
      @_foreign_entities.not_nil! << entity if entity
    end
  end
end
