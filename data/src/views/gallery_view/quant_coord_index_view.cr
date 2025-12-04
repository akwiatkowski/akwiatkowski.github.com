require "./quant_coord_const"

module GalleryView
  class QuantCoordIndexView < WidestPageView
    Log = ::Log.for(self)

    MIN_PHOTOS_TO_RENDER = 3

    getter :title

    def initialize(
      @blog : Tremolite::Blog,
      @renderers : HashQuantCoordViews,
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

      @url = "/galeria/wspolrzedne.html"
    end

    def page_header_html
      return ""
    end

    def inner_html
      return String.build do |s|
        s << "<div style=\"margin-left: auto; margin-right: auto\">\n"

        s << "<div class=\"coord-photo-table\">\n"

        @lats.reverse.each do |lat|
          s << "<div class=\"coord-photo-row\">\n"
          @lons.each do |lon|
            exists = @renderers[lat]? && @renderers[lat][lon]? && @renderers[lat][lon].photo_entities_count > MIN_PHOTOS_TO_RENDER

            if exists
              renderer = @renderers[lat][lon]

              # normalize to max 100
              max_photo_count = 50
              base_coeff = 50
              photo_coeff = ((255 - base_coeff).to_f / max_photo_count.to_f)

              photo_count = renderer.photo_entities_count
              photo_count = max_photo_count if photo_count > max_photo_count

              blue = (photo_count.to_f * photo_coeff).to_i + base_coeff
              blue = 255 if blue > 255

              green = blue / 2

              color = "rgba(0,#{green},#{blue},1)"

              additional_css_class = "coord-photo-cell-enabled"
              additional_css_style = "background-color:#{color};"

              town_name = renderer.closest_town_name
            else
              additional_css_class = "coord-photo-cell-disabled"
              additional_css_style = ""

              town_name = ""
            end

            s << "<div class=\"coord-photo-cell #{additional_css_class}\" style=\"#{additional_css_style}\" title=\"#{town_name}\">"
            if exists
              s << "<a href=\"#{renderer.not_nil!.url}\">"
              s << "<img src=\"/img/blank.gif\" class=\"coord-photo-cell-blank-link\">"
              s << "</a>"
            end
            s << "</div>\n"
          end
          s << "</div>\n"
        end

        s << "</div>\n"

        s << "</div>\n"

        s << "<script>
    function initCoordMap() {
      const grid = document.querySelector('.coord-photo-table');
      const firstRow = grid.querySelector('.coord-photo-row');
      const cols = firstRow ? firstRow.children.length : 9;
      const rows = grid.querySelectorAll('.coord-photo-row').length;

      grid.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
      grid.style.gridTemplateRows = `repeat(${rows}, 1fr)`;
    }

    // Run immediately after script loads
    initCoordMap();

    // Re-run on window resize
    window.addEventListener('resize', initCoordMap);
  </script>"
      end
    end
  end
end
