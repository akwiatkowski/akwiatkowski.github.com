class PhotoMap::IndexView < PageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @photomaps_for_tag : Hash(String, PhotoMapSvgView),
    @photomaps_for_voivodeship_big : Hash(String, PhotoMapSvgView),
    @photomaps_for_voivodeship_small : Hash(String, PhotoMapSvgView),
    @photomaps_for_post_big : Hash(Tremolite::Post, PhotoMapSvgView),
    @subtitle : String = "",
  )
  end

  getter :subtitle

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  private def inner_html_posts(s)
    # posts
    s << "<h3>Wpisy:</h3>\n"
    s << "<ul>\n"
    @photomaps_for_post_big.keys.sort.reverse.each do |post|
      photomap_view_big = @photomaps_for_post_big[post]

      s << "<li>"
      s << "<a href=\"#{photomap_view_big.url}\">"
      s << "#{post.date} - #{post.title}"
      s << "</a>"

      s << "</li>\n"
    end
    s << "</ul>\n"
  end

  private def inner_html_voivodeships(s)
    # voivodeships
    s << "<h3>Województwa:</h3>\n"
    s << "<ul>\n"
    @photomaps_for_voivodeship_big.keys.each do |voivodeship|
      photomap_view_big = @photomaps_for_voivodeship_big[voivodeship]
      photomap_view_small = @photomaps_for_voivodeship_small[voivodeship]

      s << "<li>"
      s << voivodeship
      s << ": "

      s << "<a href=\"#{photomap_view_big.url}\">"
      s << "#{photomap_view_big.zoom}"
      s << "</a>"

      s << " / "

      s << "<a href=\"#{photomap_view_small.url}\">"
      s << "#{photomap_view_small.zoom}"
      s << "</a>"

      s << "</li>\n"
    end
    s << "</ul>\n"
  end

  private def inner_html_tags(s)
    # tags
    s << "<h3>Tagi:</h3>\n"
    s << "<ul>\n"
    @photomaps_for_tag.keys.each do |tag|
      photomap_view = @photomaps_for_tag[tag]
      s << "<li>"
      s << "<a href=\"#{photomap_view.url}\">"
      s << tag
      s << "</a>"
      s << "</li>\n"
    end
    s << "</ul>\n"
  end

  # w/o header image
  def inner_html
    return String.build do |s|
      inner_html_tags(s)
      inner_html_voivodeships(s)
      inner_html_posts(s)
    end
  end
end
