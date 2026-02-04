# Area type enum for unified area entity system
# Maps to Polish URL prefixes for the website
#
# Polish inflections (with diacritics for display):
#   Town:        gmina (nominative), gminy (genitive)
#   County:      powiat, powiatu
#   Voivodeship: województwo, województwa
#   MesoRegion:  region, regionu
#   MacroRegion: obszar, obszaru
#
# URL slugs (ASCII-safe, no diacritics):
#   Voivodeship uses "wojewodztwo" / "wojewodztwa" in URLs
enum AreaType
  Town        # gmina
  County      # powiat
  Voivodeship # województwo
  MesoRegion  # region (mezoregion fizycznogeograficzny)
  MacroRegion # obszar (makroregion fizycznogeograficzny)

  # ============================================
  # English identifiers
  # ============================================

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

  # ============================================
  # Polish display names (with diacritics)
  # ============================================

  # Polish nominative singular (mianownik): gmina, powiat, województwo...
  # For display purposes only, not for URLs
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

  # Polish genitive singular (dopełniacz): gminy, powiatu, województwa...
  # For display purposes only, not for URLs
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

  # Polish nominative plural (mianownik l.mn.): gminy, powiaty, województwa...
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

  # ============================================
  # URL slugs (ASCII-safe, no diacritics)
  # ============================================

  # Nominative slug for URLs: gmina, powiat, wojewodztwo...
  # Used in show page URLs: /gmina/pobiedziska.html
  def nominative_slug : String
    case self
    when Town        then "gmina"
    when County      then "powiat"
    when Voivodeship then "wojewodztwo"
    when MesoRegion  then "region"
    when MacroRegion then "obszar"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # Genitive slug for URLs: gminy, powiatu, wojewodztwa...
  # Used after prepositions: /wpisy_dla/gminy/..., /galeria/gminy/...
  def genitive_slug : String
    case self
    when Town        then "gminy"
    when County      then "powiatu"
    when Voivodeship then "wojewodztwa"
    when MesoRegion  then "regionu"
    when MacroRegion then "obszaru"
    else                  raise "Unknown area type: #{self}"
    end
  end

  # ============================================
  # URL helpers (use slug methods)
  # ============================================

  # URL prefix for show page: /gmina/
  def url_prefix : String
    "/#{nominative_slug}/"
  end

  # URL type for post list/gallery: gminy
  def url_type : String
    genitive_slug
  end

  # ============================================
  # Legacy aliases
  # ============================================

  def polish_name : String
    polish_nominative
  end

  def polish_name_plural : String
    polish_nominative_plural
  end
end
