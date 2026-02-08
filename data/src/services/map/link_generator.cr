class Map::LinkGenerator
  def self.url_photomap_main
    return "/mapa_zdjec"
  end

  def self.url_photomap_for_post_big(post : Tremolite::Post)
    return "#{url_photomap_main}/wpis/#{post.slug}_duzy.svg"
  end

  def self.url_photomap_for_post_small(post : Tremolite::Post)
    return "#{url_photomap_main}/wpis/#{post.slug}_maly.svg"
  end

  def self.url_photomap_for_area_big(area : AreaEntity)
    type_path = case area.area_type
                when AreaType::Town        then "gmina"
                when AreaType::County      then "powiat"
                when AreaType::Voivodeship then "wojewodztwo"
                when AreaType::MesoRegion  then "region"
                when AreaType::MacroRegion then "obszar"
                else "obszar"
                end
    return "#{url_photomap_main}/#{type_path}/#{area.slug}_duzy.svg"
  end

  def self.url_photomap_for_area_small(area : AreaEntity)
    type_path = case area.area_type
                when AreaType::Town        then "gmina"
                when AreaType::County      then "powiat"
                when AreaType::Voivodeship then "wojewodztwo"
                when AreaType::MesoRegion  then "region"
                when AreaType::MacroRegion then "obszar"
                else "obszar"
                end
    return "#{url_photomap_main}/#{type_path}/#{area.slug}_maly.svg"
  end

  def self.url_photomap_for_idea(slug : String)
    return "#{url_photomap_main}/pomysl/#{slug}.svg"
  end

  def self.url_photomap_for_main(slug : String)
    return "#{url_photomap_main}/globalne/#{slug}.svg"
  end

  def self.url_photomap_for_tag(slug : String)
    return "#{url_photomap_main}/tag/#{slug}.svg"
  end
end
