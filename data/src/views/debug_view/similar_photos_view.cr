require "../wider_page_view"

module DebugView
  class SimilarPhotosView < WiderPageView
    Log = ::Log.for(self)

    MAX_SAMPLE_GROUPS = 5
    THRESHOLDS        = (3..12).to_a

    alias GroupResult = NamedTuple(threshold: Int32, total: Int32, samples: Array(Array(PhotoEntity)))

    def initialize(context : RenderContext)
      super(context: context, url: "/debug/similar_photos")
      @title = "Debug: Podobne zdjęcia (pHash)"
      @subtitle = ""
      @image_url = context.posts.last?.try(&.image_url) || ""

      entries = context.photo_analysis_cache.load_all
      @has_data = !entries.empty?
      @results = [] of GroupResult

      if @has_data
        lookup = build_photo_lookup(context)
        total_photos = lookup.size
        seen_keys = Set(String).new

        THRESHOLDS.each do |t|
          service = PhotoSimilarityService.new(entries, lookup, threshold: t)
          all_groups = service.find_groups

          # Stop if nearly all photos end up in groups — not useful
          grouped_count = all_groups.sum(&.size)
          break if total_photos > 0 && grouped_count > total_photos * 0.8

          # Keep only groups with at least one photo not seen at lower thresholds
          new_groups = all_groups.select do |group|
            group.any? { |pe| !seen_keys.includes?("#{pe.post_slug}/#{pe.image_filename}") }
          end.sort_by { |g| -g.size }

          # Track all grouped photos for next iteration
          all_groups.each do |group|
            group.each { |pe| seen_keys << "#{pe.post_slug}/#{pe.image_filename}" }
          end

          next if new_groups.empty?

          samples = new_groups.first(MAX_SAMPLE_GROUPS)
          @results << {threshold: t, total: new_groups.size, samples: samples}
        end
      end
    end

    def add_to_sitemap?
      false
    end

    getter :image_url, :title, :subtitle

    def inner_html
      String.build do |s|
        unless @has_data
          s << "<p>Brak danych — uruchom analizę zdjęć.</p>\n"
          next
        end

        if @results.empty?
          s << "<p>Brak grup podobnych zdjęć.</p>\n"
          next
        end

        @results.each do |result|
          s << "<h2>Hamming distance = #{result[:threshold]}"
          s << " <small style=\"color:#888;\">(#{result[:total]} nowych grup)</small>"
          s << "</h2>\n"

          result[:samples].each_with_index do |group, i|
            s << "<div style=\"margin-bottom:1rem;padding:0.5rem;border:1px solid #ccc;border-radius:4px;\">\n"
            s << "<h5>Grupa #{i + 1} (#{group.size} zdjęć)</h5>\n"
            s << "<div style=\"display:flex;flex-wrap:wrap;gap:6px;\">\n"
            group.each do |pe|
              s << "<div style=\"text-align:center;\">"
              s << "<a href=\"#{pe.full_image_src}\">"
              s << "<img src=\"#{pe.thumbnail_image_src}\" alt=\"#{pe.image_filename}\" "
              s << "style=\"max-height:112px;\" loading=\"lazy\">"
              s << "</a>"
              s << "<div style=\"font-size:0.7rem;\">#{pe.post_slug}</div>"
              s << "</div>\n"
            end
            s << "</div>\n"
            s << "</div>\n"
          end

          remaining = result[:total] - result[:samples].size
          if remaining > 0
            s << "<p style=\"color:#888;\">...i #{remaining} więcej grup</p>\n"
          end
        end
      end
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
