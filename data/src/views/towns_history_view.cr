class TownsHistoryView < PageView
  def initialize(@blog : Tremolite::Blog, @url : String)
    @image_url = @blog.data_manager.not_nil!["towns_history.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["towns_history.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["towns_history.subtitle"].as(String)

    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
  end

  getter :image_url, :title, :subtitle

  def inner_html
    s = "<ol>"

    @blog.data_manager.not_nil!.voivodeships.not_nil!.each do |voivodeship|
      s += "<li>\n<h2>#{voivodeship.name}</h2>\n"
      s += "<ul>\n"

      towns = Array(Tuple(TownEntity, (Time))).new
      towns_in_voivodeship(voivodeship).each do |t|
        vt = visited_since(t)
        towns << {t, vt.not_nil!} unless vt.nil?
      end

      towns.sort{|a,b| a[1] <=> b[1]}.map{|a| a[0]}.each do |town|
        s += town_element(town)
      end

      s += "</ul></li>\n"
    end

    return s
  end

  def towns_in_voivodeship(voivodeship)
    @blog.data_manager.not_nil!.towns.not_nil!.select { |t| t.voivodeship == voivodeship.slug }
  end

  def visited_since(town)
    posts_for_town = @posts.select { |post| post.towns && post.towns.not_nil!.includes?(town.slug )}
    if posts_for_town.size > 0
      return posts_for_town.sort{|a,b| a.time <=> b.time }.first.time
    else
      return nil
    end
  end

  def town_element(town)
    s = "<li><a href=\"#{town.url}\">#{town.name}</a>"

    if town.lat && town.lon
      # s += "<a class=\"small\" href"
      ump_link = "http://mapa.ump.waw.pl/ump-www/?zoom=13&lat=#{town.lat}&lon=#{town.lon}&layers=B000000FFFFTFF&mlat=#{town.lat}&mlon=#{town.lon}"
      s += " <a href=\"#{ump_link}\" target=\"_blank\"><span class=\"small glyphicon glyphicon-map-marker\"></span></a>"
    end

    # posts
    posts_for_town = @posts.select { |post| post.towns && post.towns.not_nil!.includes?(town.slug )}
    if posts_for_town.size > 0
      # s += " - #{posts_for_town.size} wpisów od "
      s += " - od "
      s += "<strong>"
      s += posts_for_town.sort{|a,b| a.time <=> b.time }.first.date
      s += "</strong>"
    end

    s += "</li>\n"
    return s
  end
end
