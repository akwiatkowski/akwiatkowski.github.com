module GalleryView
  class IndexView < PageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @tag_gallery_index_view : TagIndexView,
      @lens_gallery_index_view : LensIndexView,
      @camera_gallery_index_view : CameraIndexView,
      @focal_length_gallery_index_view : FocalLengthIndexView,
      @iso_gallery_index_view : IsoIndexView,
      @exposure_gallery_index_view : ExposureIndexView,
      @quant_coord_index_view : QuantCoordIndexView,
    )
      @url = "/gallery"
    end

    def subtitle
      @blog.data_manager.not_nil!["gallery.subtitle"]
    end

    def title
      @blog.data_manager.not_nil!["gallery.title"]
    end

    def image_url
      @image_url ||= @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    end

    def inner_html
      return String.build do |s|
        s << "<ul>\n"
        # unfortunately creating array with all these classes
        # is a bit complicated task
        s << content_for_index_renderer(@tag_gallery_index_view)
        s << content_for_index_renderer(@lens_gallery_index_view)
        s << content_for_index_renderer(@camera_gallery_index_view)
        s << content_for_index_renderer(@focal_length_gallery_index_view)
        s << content_for_index_renderer(@iso_gallery_index_view)
        s << content_for_index_renderer(@exposure_gallery_index_view)
        s << content_additional
        s << "</ul>\n"
      end
    end

    def content_for_index_renderer(index_renderer)
      return String.build do |s|
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
    end

    def content_additional
      return String.build do |s|
        s << "<li>\n"

        s << "<a href=\"#{@quant_coord_index_view.url}\">"
        s << @quant_coord_index_view.title
        s << "</a>"

        s << "</li>\n"
      end
    end
  end
end
