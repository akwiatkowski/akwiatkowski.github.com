# Area type enum for unified area entity system
# Maps to Polish URL prefixes for the website
enum AreaType
  Town        # gmina
  County      # powiat
  Voivodeship # województwo
  MesoRegion  # region (mezoregion fizycznogeograficzny)
  MacroRegion # obszar (makroregion fizycznogeograficzny)

  # Polish URL prefix for this area type
  def url_prefix : String
    case self
    when Town        then "/gminy/"
    when County      then "/powiaty/"
    when Voivodeship then "/wojewodztwa/"
    when MesoRegion  then "/regiony/"
    when MacroRegion then "/obszary/"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Polish type name for gallery/post list URLs (without slashes)
  def url_type : String
    case self
    when Town        then "gminy"
    when County      then "powiaty"
    when Voivodeship then "wojewodztwa"
    when MesoRegion  then "regiony"
    when MacroRegion then "obszary"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Human-readable Polish name
  def polish_name : String
    case self
    when Town        then "gmina"
    when County      then "powiat"
    when Voivodeship then "województwo"
    when MesoRegion  then "region"
    when MacroRegion then "obszar"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Human-readable Polish plural name
  def polish_name_plural : String
    case self
    when Town        then "gminy"
    when County      then "powiaty"
    when Voivodeship then "województwa"
    when MesoRegion  then "regiony"
    when MacroRegion then "obszary"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Field name in payload.json for filtering posts
  def payload_field : String
    case self
    when Town        then "towns"
    when County      then "counties"
    when Voivodeship then "voivodeships"
    when MesoRegion  then "meso_regions"
    when MacroRegion then "macro_regions"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Polygon directory name (plural)
  def polygon_dir : String
    case self
    when Town        then "towns"
    when County      then "counties"
    when Voivodeship then "voivodeships"
    when MesoRegion  then "meso_regions"
    when MacroRegion then "macro_regions"
    else                  raise "Unknown area type: #{self}"
    end
  end
end
