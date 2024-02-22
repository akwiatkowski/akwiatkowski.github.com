class PhotoMap::IndexView < PageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    @photomaps_for_tag : Hash(String, PhotoMap::MultiplePhotoEntitiesGridMapSvgView),
    @photomaps_for_voivodeship_big : Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView),
    @photomaps_for_voivodeship_small : Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView),
    @photomaps_for_post_big : Hash(Tremolite::Post, PhotoMap::PostBigMapSvgView),
    @photomaps_for_post_small : Hash(Tremolite::Post, PhotoMap::PostRouteMapSvgView),
    # TODO: add abstract class
    @photomaps_global : Hash(String, PhotoMap::AbstractSvgView),
    @subtitle : String = ""
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
      photomap_view_small = @photomaps_for_post_small[post]

      s << "<li>"
      s << "<a href=\"#{post.url}\">"
      s << "#{post.date} - #{post.title}"
      s << "</a> "

      s << "<a href=\"#{photomap_view_big.url}\">"
      s << "#{photomap_view_big.zoom}x"
      s << "</a>, "

      s << "<a href=\"#{photomap_view_small.url}\">"
      s << "#{photomap_view_small.zoom}x"

      if post.specified_suggested_photo_map_zoom?
        s << "&#9938;"
      end

      s << "</a>"
      s << " "

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
    @photomaps_for_tag.keys.each do |tag_slug|
      tag_name = @blog.data_manager.not_nil!["gallery.#{tag_slug}.title"]?

      if tag_name.nil?
        Log.error { "photo tag '#{tag_slug}' missing from config.yml" }
        next
      end

      photomap_view = @photomaps_for_tag[tag_slug]

      s << "<li>"
      s << "<a href=\"#{photomap_view.url}\">"
      s << tag_name.to_s
      s << "</a>"
      s << "</li>\n"
    end
    s << "</ul>\n"
  end

  private def inner_html_globals(s)
    # tags
    s << "<h3>Ogólne:</h3>\n"
    s << "<ul>\n"
    @photomaps_global.keys.each do |tag|
      photomap_view = @photomaps_global[tag]
      s << "<li>"
      s << "<a href=\"#{photomap_view.url}\">"
      s << tag
      s << "</a>"

      s << " (#{photomap_view.zoom}x)"

      s << "</li>\n"
    end
    s << "</ul>\n"
  end

  # w/o header image
  def inner_html
    return String.build do |s|
      inner_html_globals(s)
      inner_html_tags(s)
      inner_html_voivodeships(s)
      inner_html_posts(s)
    end
  end
end
