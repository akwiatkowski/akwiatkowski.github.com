require "../wider_page_view"

module DebugView
  class ColorPhotosView < WiderPageView
    Log = ::Log.for(self)

    def initialize(context : RenderContext)
      super(context: context, url: "/debug/color_photos")
      @title = "Debug: Podobne kolory"
      @subtitle = ""
      @image_url = context.posts.last?.try(&.image_url) || ""

      entries = context.photo_analysis_cache.load_all
      if entries.empty?
        @groups = [] of Array(PhotoEntity)
        @avg_colors = Hash(String, Array(Int32)).new
      else
        lookup = build_photo_lookup(context)
        service = ColorSimilarityService.new(entries, lookup)
        @groups = service.find_groups

        # Build avg_rgb lookup for color swatches
        @avg_colors = Hash(String, Array(Int32)).new
        entries.each do |e|
          @avg_colors["#{e.post_slug}/#{e.image_filename}"] = e.avg_rgb
        end
      end
    end

    def add_to_sitemap?
      false
    end

    getter :image_url, :title, :subtitle

    def inner_html
      String.build do |s|
        s << "<h2>Grupy podobnych kolorów (Euclidean distance ≤ 30)</h2>\n"

        if @groups.empty?
          s << "<p>Brak danych — uruchom analizę zdjęć.</p>\n"
          next
        end

        s << "<p>Znaleziono <strong>#{@groups.size}</strong> grup.</p>\n"

        @groups.each_with_index do |group, i|
          # Compute average color for the group
          avg = group_avg_color(group)
          bg = "rgb(#{avg[0]},#{avg[1]},#{avg[2]})"

          s << "<div style=\"margin-bottom:1.5rem;padding:0.5rem;border:1px solid #ccc;border-radius:4px;\">\n"
          s << "<h5>Grupa #{i + 1} (#{group.size} zdjęć) "
          s << "<span style=\"display:inline-block;width:20px;height:20px;background:#{bg};border:1px solid #999;vertical-align:middle;border-radius:3px;\"></span>"
          s << "</h5>\n"
          s << "<div style=\"display:flex;flex-wrap:wrap;gap:6px;\">\n"
          group.each do |pe|
            key = "#{pe.post_slug}/#{pe.image_filename}"
            rgb = @avg_colors[key]?
            swatch_style = rgb ? "background:rgb(#{rgb[0]},#{rgb[1]},#{rgb[2]});" : ""

            s << "<div style=\"text-align:center;\">"
            s << "<a href=\"#{pe.full_image_src}\">"
            s << "<img src=\"#{pe.thumbnail_image_src}\" alt=\"#{pe.image_filename}\" "
            s << "style=\"max-height:112px;\" loading=\"lazy\">"
            s << "</a>"
            s << "<div style=\"display:flex;align-items:center;justify-content:center;gap:3px;\">"
            s << "<span style=\"display:inline-block;width:12px;height:12px;#{swatch_style}border:1px solid #999;border-radius:2px;\"></span>"
            s << "<span style=\"font-size:0.7rem;\">#{pe.post_slug}</span>"
            s << "</div>"
            s << "</div>\n"
          end
          s << "</div>\n"
          s << "</div>\n"
        end
      end
    end

    private def group_avg_color(group : Array(PhotoEntity)) : Array(Int32)
      r, g, b, count = 0, 0, 0, 0
      group.each do |pe|
        key = "#{pe.post_slug}/#{pe.image_filename}"
        if rgb = @avg_colors[key]?
          r += rgb[0]
          g += rgb[1]
          b += rgb[2]
          count += 1
        end
      end
      return [128, 128, 128] if count == 0
      [r // count, g // count, b // count]
    end

    private def build_photo_lookup(context : RenderContext) : Hash(String, PhotoEntity)
      lookup = Hash(String, PhotoEntity).new
      context.exif_db.all_flatten_photo_entities.each do |pe|
        lookup["#{pe.post_slug}/#{pe.image_filename}"] = pe
      end
      lookup
    end
  end
end
