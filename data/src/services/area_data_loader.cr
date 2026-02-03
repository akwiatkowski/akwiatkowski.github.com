require "yaml"
require "../models/area_type"
require "../models/area_entity"
require "../models/area_association"

# Loads area data from:
# 1. data/config/areas/*.yml - area entity definitions (generated from data/external/)
# 2. cache/areas_for_post/<slug>.yml - per-post route distance data
class AreaDataLoader
  Log = ::Log.for(self)

  THRESHOLD_DEFAULT = 1.0 # percent

  getter areas : Array(AreaEntity)
  getter threshold : Float64

  def initialize(@config_path : String, @cache_path : String, @threshold : Float64 = THRESHOLD_DEFAULT)
    @areas = [] of AreaEntity
    @areas_by_type = {} of AreaType => Array(AreaEntity)
  end

  # Load all area entities from config files
  def load_areas
    @areas.clear
    @areas_by_type.clear

    load_area_file("towns", AreaType::Town)
    load_area_file("counties", AreaType::County)
    load_area_file("voivodeships", AreaType::Voivodeship)
    load_area_file("meso_regions", AreaType::MesoRegion)
    load_area_file("macro_regions", AreaType::MacroRegion)

    Log.info { "Loaded #{@areas.size} areas total" }
  end

  private def load_area_file(filename : String, area_type : AreaType)
    path = File.join([@config_path, "areas", "#{filename}.yml"])

    unless File.exists?(path)
      Log.warn { "Area config file not found: #{path}" }
      return
    end

    data = YAML.parse(File.read(path))
    count = 0

    data.as_a.each do |item|
      entity = AreaEntity.from_yaml(item, area_type)
      @areas << entity
      count += 1
    end

    Log.info { "Loaded #{count} #{area_type}s from #{filename}.yml" }
  end

  # Get areas filtered by type (memoized)
  def areas_of_type(type : AreaType) : Array(AreaEntity)
    @areas_by_type[type] ||= @areas.select { |a| a.area_type == type }
  end

  # Shortcut accessors
  def towns : Array(AreaEntity)
    areas_of_type(AreaType::Town)
  end

  def counties : Array(AreaEntity)
    areas_of_type(AreaType::County)
  end

  def voivodeships : Array(AreaEntity)
    areas_of_type(AreaType::Voivodeship)
  end

  def meso_regions : Array(AreaEntity)
    areas_of_type(AreaType::MesoRegion)
  end

  def macro_regions : Array(AreaEntity)
    areas_of_type(AreaType::MacroRegion)
  end

  # Find area by type and slug
  def area_by_slug(type : AreaType, slug : String) : AreaEntity?
    areas_of_type(type).find { |a| a.slug == slug }
  end

  # Load route distance data for a specific post
  # Returns hash of AreaType => Array(AreaAssociation)
  def load_for_post(post_slug : String) : Hash(AreaType, Array(AreaAssociation))
    result = {} of AreaType => Array(AreaAssociation)

    path = File.join([@cache_path, "areas_for_post", "#{post_slug}.yml"])

    unless File.exists?(path)
      return result
    end

    data = YAML.parse(File.read(path))

    # Initialize empty arrays for each type
    AreaType.each do |type|
      result[type] = [] of AreaAssociation
    end

    # Sum distances across all routes in the post
    data.as_a.each do |route|
      add_associations(result, route, "towns", AreaType::Town)
      add_associations(result, route, "counties", AreaType::County)
      add_associations(result, route, "voivodeships", AreaType::Voivodeship)
      add_associations(result, route, "meso_regions", AreaType::MesoRegion)
      add_associations(result, route, "macro_regions", AreaType::MacroRegion)
    end

    # Apply threshold filter and sort
    result.each do |type, associations|
      result[type] = associations
        .select { |a| a.above_threshold?(@threshold) }
        .sort
    end

    result
  end

  private def add_associations(
    result : Hash(AreaType, Array(AreaAssociation)),
    route : YAML::Any,
    key : String,
    area_type : AreaType
  )
    return unless route[key]?

    route[key].as_a.each do |item|
      assoc = AreaAssociation.from_yaml(item, area_type)

      # Check if we already have this area (from another route)
      existing = result[area_type].find { |a| a.slug == assoc.slug }

      if existing
        # Sum the distances (would need mutable struct or recreate)
        # For now, keep the one with higher distance
        if assoc.distance_meters > existing.distance_meters
          result[area_type].reject! { |a| a.slug == assoc.slug }
          result[area_type] << assoc
        end
      else
        result[area_type] << assoc
      end
    end
  end

  # Get all area slugs for a post (across all types, filtered by threshold)
  def area_slugs_for_post(post_slug : String) : Hash(AreaType, Array(String))
    associations = load_for_post(post_slug)
    result = {} of AreaType => Array(String)

    associations.each do |type, assocs|
      result[type] = assocs.map(&.slug)
    end

    result
  end
end
