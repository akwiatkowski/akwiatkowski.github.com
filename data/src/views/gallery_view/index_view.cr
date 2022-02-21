module GalleryView
  class IndexView < PageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @tag_gallery_index_view : TagIndexView
    )
      @url = "/gallery"
    end

    # main params of this page
    def title
      @blog.data_manager.not_nil!["gallery.subtitle"]
    end

    def title
      @blog.data_manager.not_nil!["gallery.title"]
    end

    def image_url
      @image_url ||= @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    end

    def index_renderers
      return [
        @tag_gallery_index_view,
      ]
    end

    def inner_html
      return String.build do |s|
        s << "<ul>\n"
        index_renderers.each do |index_renderer|
          s << "<li>\n"

          s << "<a href=\"#{index_renderer.url}\">"
          s << index_renderer.title
          s << "</a>"
          s << ":"

          s << "<ul>\n"
          index_renderer.filtered_renderers.each do |sub_renderer|
            s << "<li>\n"

            s << "<a href=\"#{sub_renderer.url}\">"
            s << sub_renderer.title
            s << "</a>"
            s << " - #{sub_renderer.photo_entities_count} zdjęć"

            s << "</li>\n"
          end
          s << "</ul>\n"

          s << "</li>\n"
        end
        s << "</ul>\n"
      end
    end
  end
end
