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
    else raise "Unknown area type: #{self}"
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
    else raise "Unknown area type: #{self}"
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
    else raise "Unknown area type: #{self}"
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
    else raise "Unknown area type: #{self}"
    end
  end
end
