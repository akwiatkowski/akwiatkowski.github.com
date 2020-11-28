# list of lens showcase
class LensGalleryIndexView < PageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @lens_renderers : Array(LensGalleryView)
  )
    # reverse ordered only with photos
    @lend_renderers_with_content = @lens_renderers.select do |lr|
      lr.photo_entities_count > 0
    end.sort do |a,b|
      a.photo_entities_count <=> b.photo_entities_count
    end.uniq do |lr|
      # there was problem with doubled viewers because of
      # multiple kind of "misc" lenses
      lr.url
    end.reverse.as(Array(LensGalleryView))

    # TODO
    @image_url = ""
    @subtitle = ""
    @title = ""

    @url = "/gallery/lens/"
  end

  getter :image_url, :title, :subtitle, :year, :url

  def inner_html
    return String.build do |s|
      s << "<ul>\n"
      @lend_renderers_with_content.each do |renderer|
        s << "<li>"
        s << "<a href=\"#{renderer.url}\">#{renderer.title}</a> - #{renderer.photo_entities_count}"
        s << "</li>\n"
      end
      s << "</ul>\n"
    end
  end
end
