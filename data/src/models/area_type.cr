# Area type enum for unified area entity system
# Maps to Polish URL prefixes for the website
#
# Polish inflections:
#   Town:        gmina (nominative), gminy (genitive)
#   County:      powiat, powiatu
#   Voivodeship: województwo, województwa
#   MesoRegion:  region, regionu
#   MacroRegion: obszar, obszaru
enum AreaType
  Town        # gmina
  County      # powiat
  Voivodeship # województwo
  MesoRegion  # region (mezoregion fizycznogeograficzny)
  MacroRegion # obszar (makroregion fizycznogeograficzny)

  # English plural form - used for payload fields, polygon directories, etc.
  def english_plural : String
    case self
    when Town        then "towns"
    when County      then "counties"
    when Voivodeship then "voivodeships"
    when MesoRegion  then "meso_regions"
    when MacroRegion then "macro_regions"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Field name in payload.json for filtering posts
  def payload_field : String
    english_plural
  end

  # Polygon directory name (plural)
  def polygon_dir : String
    english_plural
  end

  # Polish nominative singular (mianownik): gmina, powiat, ...
  # Used in show URLs: /gmina/pobiedziska.html
  def polish_nominative : String
    case self
    when Town        then "gmina"
    when County      then "powiat"
    when Voivodeship then "województwo"
    when MesoRegion  then "region"
    when MacroRegion then "obszar"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Polish genitive singular (dopełniacz): gminy, powiatu, ...
  # Used after prepositions: wpisy_dla/gminy/..., galeria/gminy/...
  def polish_genitive : String
    case self
    when Town        then "gminy"
    when County      then "powiatu"
    when Voivodeship then "województwa"
    when MesoRegion  then "regionu"
    when MacroRegion then "obszaru"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Polish nominative plural (mianownik l.mn.): gminy, powiaty, ...
  def polish_nominative_plural : String
    case self
    when Town        then "gminy"
    when County      then "powiaty"
    when Voivodeship then "województwa"
    when MesoRegion  then "regiony"
    when MacroRegion then "obszary"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # URL prefix for show page (nominative): /gmina/
  def url_prefix : String
    "/#{polish_nominative}/"
  end

  # URL type for post list/gallery (genitive): gminy
  def url_type : String
    polish_genitive
  end

  # Legacy aliases
  def polish_name : String
    polish_nominative
  end

  def polish_name_plural : String
    polish_nominative_plural
  end
end
