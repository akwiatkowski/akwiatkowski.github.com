require "./quant_coord_const"

module GalleryView
  class QuantCoordIndexView < WidestPageView
    Log = ::Log.for(self)

    MIN_PHOTOS_TO_RENDER = 3

    getter :title

    def initialize(
      @blog : Tremolite::Blog,
      @renderers : HashQuantCoordViews
    )
      @photo_coord_quant_cache = @blog.data_manager.not_nil!.photo_coord_quant_cache.not_nil!.as(
        PhotoCoordQuantCache
      )
      @lats = Array(Float32).new
      @lons = Array(Float32).new
      @photo_coord_quant_cache.cache.keys.each do |key|
        @lats << key[:lat]
        @lons << key[:lon]
      end
      @lats = @lats.uniq.sort
      @lons = @lons.uniq.sort

      @image_url = ""
      @subtitle = "zdjęcia podzielone na współrzędne"
      @title = "Współrzędne"

      @url = "/gallery/coord/"
    end

    def page_header_html
      return ""
    end

    def inner_html
      return String.build do |s|
        s << "<div style=\"margin-left: auto; margin-right: auto\">\n"

        s << "<table class=\"coord-photo-table\">\n"

        @lats.reverse.each do |lat|
          s << "<tr>\n"
          @lons.each do |lon|
            exists = @renderers[lat]? && @renderers[lat][lon]? && @renderers[lat][lon].photo_entities_count > MIN_PHOTOS_TO_RENDER

            if exists
              # normalize to max 100
              photo_count = @renderers[lat][lon].photo_entities_count
              photo_count = 100 if photo_count > 100

              green_coeff = (photo_count.to_f * 2.05).to_i + 50

              color = "rgba(0,#{green_coeff},0,1)"

              additional_css_class = "coord-photo-cell-enabled"
              additional_css_style = "background-color:#{color};"
            else
              additional_css_class = "coord-photo-cell-disabled"
              additional_css_style = ""
            end

            s << "<td class=\"coord-photo-cell #{additional_css_class}\" style=\"#{additional_css_style}\">"
            if exists
              # TODO: use url from renderers
              s << "<a href=\"/gallery/coord/#{lat},#{lon}\">"
              s << "<img src=\"/img/blank.gif\" class=\"coord-photo-cell-blank-link\">"
              s << "</a>"
            end
            s << "</td>\n"
          end
          s << "</tr>\n"
        end

        s << "</table>\n"

        s << "</div>\n"
      end
    end
  end
end
