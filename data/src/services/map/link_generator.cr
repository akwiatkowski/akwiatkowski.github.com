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

  def self.url_photomap_for_voivodeship_big(voivodeship : VoivodeshipEntity)
    return "#{url_photomap_main}/wojewodztwo/#{voivodeship.slug}_duzy.svg"
  end

  def self.url_photomap_for_voivodeship_small(voivodeship : VoivodeshipEntity)
    return "#{url_photomap_main}/wojewodztwo/#{voivodeship.slug}_maly.svg"
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
