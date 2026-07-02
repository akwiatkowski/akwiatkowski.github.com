require "yaml"
require "./area"
require "./area_type"

module AreaMatcher::Loader
  Log = ::Log.for(self)

  # Detect if coordinates are [lat, lon] (true) or [lon, lat] (false)
  # Poland: lat ~49-55, lon ~14-24
  def self.is_latlon_order?(coords : Array(Array(Float64))) : Bool
    return false if coords.empty?
    first, second = coords[0]
    (40.0 <= first <= 60.0) && (10.0 <= second <= 30.0)
  end

  # Normalize coordinates to [lon, lat] for GEOS
  # Input can be either [lat, lon] or [lon, lat]
  def self.normalize_coords(coords : Array(Array(Float64)), swap : Bool) : Array(Array(Float64))
    if swap
      coords.map { |c| [c[1], c[0]] }
    else
      coords.dup
    end
  end

  # Parse coords from YAML
  def self.parse_coords(data : YAML::Any?) : Array(Array(Float64))
    return [] of Array(Float64) if data.nil?
    data.as_a.map { |point| [point[0].as_f, point[1].as_f] }
  rescue
    [] of Array(Float64)
  end

  # Load towns from YAML
  # Format: [lat, lon] -> needs swap
  def self.load_towns(path : String) : Array(Area)
    load_administrative_areas(path, AreaType::Town)
  end

  # Load counties from YAML
  # Format: [lat, lon] -> needs swap
  def self.load_counties(path : String) : Array(Area)
    load_administrative_areas(path, AreaType::County)
  end

  # Load voivodeships from YAML
  # Format: [lat, lon] -> needs swap
  def self.load_voivodeships(path : String) : Array(Area)
    load_administrative_areas(path, AreaType::Voivodeship)
  end

  # Generic loader for administrative areas (towns, counties, voivodeships)
  # These have: name, slug, voivodeship, terc, polygon in [lat, lon] format
  private def self.load_administrative_areas(path : String, area_type : AreaType) : Array(Area)
    areas = [] of Area

    unless File.exists?(path)
      Log.error { "File not found: #{path}" }
      return areas
    end

    data = YAML.parse(File.read(path)).as_a

    data.each do |item|
      slug = item["slug"]?.try(&.as_s?) || ""
      name = item["name"]?.try(&.as_s?)
      voivodeship = item["voivodeship"]?.try(&.as_s?)
      terc = item["terc"]?.try(&.as_s?) || item["terc"]?.try(&.as_i?.try(&.to_s))

      raw_coords = parse_coords(item["polygon"]?)

      if slug.empty?
        Log.error { "#{area_type} missing slug" }
        next
      end

      if raw_coords.empty?
        Log.warn { "#{area_type} #{slug} has empty polygon" }
        next
      end

      # Administrative areas use [lat, lon], convert to [lon, lat]
      swap = is_latlon_order?(raw_coords)
      coords = normalize_coords(raw_coords, swap)

      areas << Area.new(
        slug: slug,
        name: name,
        area_type: area_type,
        coords: coords,
        voivodeship: voivodeship,
        terc: terc
      )
    end

    Log.info { "Loaded #{areas.size} #{area_type}s from #{path}" }
    areas
  end

  # Load meso regions from YAML
  # Format: [lon, lat] -> no swap needed
  def self.load_meso_regions(path : String) : Array(Area)
    load_geographic_regions(path, AreaType::MesoRegion)
  end

  # Load macro regions from YAML
  # Format: [lon, lat] -> no swap needed
  def self.load_macro_regions(path : String) : Array(Area)
    load_geographic_regions(path, AreaType::MacroRegion)
  end

  # Load mega regions from YAML
  # Format: [lon, lat] -> no swap needed
  def self.load_mega_regions(path : String) : Array(Area)
    load_geographic_regions(path, AreaType::MegaRegion)
  end

  # Load subprovinces from YAML
  # Format: [lon, lat] -> no swap needed
  # Uses kod_prowincja field
  def self.load_subprovinces(path : String) : Array(Area)
    load_geographic_regions(path, AreaType::Subprovince)
  end

  # Load provinces from YAML
  # Format: [lon, lat] -> no swap needed
  # Uses kod_megaregion field
  def self.load_provinces(path : String) : Array(Area)
    load_geographic_regions(path, AreaType::Province)
  end

  # Generic loader for geographic regions (meso, macro, mega, subprovince, province)
  # These have: name, slug, kod/kod_prowincja/kod_megaregion, polygon in [lon, lat] format
  private def self.load_geographic_regions(path : String, area_type : AreaType) : Array(Area)
    areas = [] of Area

    unless File.exists?(path)
      Log.error { "File not found: #{path}" }
      return areas
    end

    data = YAML.parse(File.read(path)).as_a

    data.each do |item|
      slug = item["slug"]?.try(&.as_s?) || ""
      name = item["name"]?.try(&.as_s?)

      # Code field varies: "kod" for most, "kod_prowincja" for subprovinces, "kod_megaregion" for provinces
      code = item["kod"]?.try(&.as_s?) ||
             item["kod"]?.try(&.as_i?.try(&.to_s)) ||
             item["kod_prowincja"]?.try(&.as_s?) ||
             item["kod_prowincja"]?.try(&.as_i?.try(&.to_s)) ||
             item["kod_megaregion"]?.try(&.as_s?) ||
             item["kod_megaregion"]?.try(&.as_i?.try(&.to_s))

      raw_coords = parse_coords(item["polygon"]?)

      if slug.empty?
        Log.error { "#{area_type} missing slug" }
        next
      end

      if raw_coords.empty?
        Log.warn { "#{area_type} #{slug} has empty polygon" }
        next
      end

      # Geographic regions use [lon, lat], check anyway and swap if needed
      swap = is_latlon_order?(raw_coords)
      coords = normalize_coords(raw_coords, swap)

      areas << Area.new(
        slug: slug,
        name: name,
        area_type: area_type,
        coords: coords,
        code: code
      )
    end

    Log.info { "Loaded #{areas.size} #{area_type}s from #{path}" }
    areas
  end
end
