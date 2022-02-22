require "../page_view"

module GalleryView
  class AbstractIndexView < PageView
    getter :image_url, :title, :subtitle, :year, :url, :renderers, :filtered_renderers

    def inner_html
      return String.build do |s|
        s << "<ul>\n"
        @filtered_renderers.each do |renderer|
          s << "<li>"
          s << "<a href=\"#{renderer.url}\">#{renderer.title}</a> - #{renderer.photo_entities_count} zdjęć"
          s << "</li>\n"
        end
        s << "</ul>\n"
      end
    end
  end
end
