require "../wider_page_view"

module DynamicView
  class DebugPostMissingPhotosExifView < WiderPageView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog)
      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
      @image_url = generate_image_url.as(String)
      @title = "Problemy z exif"
      @subtitle = "cache albo problem z importem/parsowaniem"
      @url = "/debug/posts_photos_missing_exif"
    end

    getter :image_url, :title, :subtitle
    property :url

    def inner_html
      return String.build do |s|
        s << "<table class=\"table small\">\n"

        s << "<tr class=\"\">\n"
        s << "<th></th>\n"
        TABLE_HEADERS.values.each do |header_title|
          s << "<th>#{header_title}</th>\n"
        end
        s << "</tr>\n"

        # filter by severity of lack of readiness of post
        # and then coeff
        post_readiness = @posts.map { |post| post_readiness_tuple(post) }.sort do |a, b|
          missing_latlon_count_comparison = b[:missing_factor] <=> a[:missing_factor]
          date_comparison = a[:date] <=> b[:date]

          if missing_latlon_count_comparison == 0
            date_comparison
          else
            missing_latlon_count_comparison
          end
        end

        post_readiness.each_with_index do |tuple, i|
          s << "<tr class=\"#{tuple[:css]}\">\n"
          s << "<td>#{i + 1}</td>\n"
          TABLE_HEADERS.keys.each do |key|
            value = tuple[key]
            button_css = tuple[:css].gsub("text-", "btn-")

            # bootstrap icons https://icons.getbootstrap.com
            if value.to_s == true.to_s
              inner_symbol = "&check;"
              if TABLE_ICONS[key]?
                # not happy with using class method
                inner_symbol = Tremolite::Views::BaseView.bootstrap_icon(TABLE_ICONS[key]?.to_s)
              end

              value_string = "<button type=\"button\" class=\"btn btn-sm #{button_css}\" title=\"#{TABLE_HEADERS[key]}\">#{inner_symbol}</button>\n"
            elsif value.to_s == false.to_s
              value_string = ""
              # blank instead of "&cross;"
            else
              value_string = value.to_s
            end

            if key == :title
              url = tuple[:post].url
              value_string = "<a href=\"#{url}\" class=\"#{tuple[:css]}\">#{value_string}</a>"
            end

            if key == :title
              klass_name = "truncate"
            else
              klass_name = ""
            end

            s << "<td class=\"#{klass_name}\">#{value_string}</td>\n"
          end
          s << "</tr>\n"
        end
        s << "</table>\n"
      end
    end

    TABLE_HEADERS = {
      title:                "Tytuł",
      ready:                "Done",
      missing_factor:       "% brak geo",
      missing_latlon_count: "Brak geo",
      all_photos_count:     "Wszystkie zdj",
      published_count:      "Zdjęcia wpisu",
    }

    TABLE_ICONS = {
      ready:          "gift-fill",
      text_included:  "file-earmark-text",
      all_references: "tags",
      has_land:       "signpost",
      photo_count:    "stack", # not used
      route:          "signpost",
    }

    def post_readiness_tuple(post)
      missing_latlon = post.uploaded_photo_entities.select { |pe| pe.exif.lat.nil? || pe.exif.lon.nil? }
      missing_latlon_count = missing_latlon.size

      published_count = post.published_photo_entities.size
      all_photos_count = post.uploaded_photo_entities.size

      missing_factor = 0
      if published_count > 1 && all_photos_count > 1 && missing_latlon_count > 1
        missing_factor = (100.0 * missing_latlon_count.to_f / all_photos_count.to_f).to_i
      end

      return {
        post:                 post,
        date:                 post.date,
        ready:                post.ready?,
        title:                "#{post.date}: #{post.title}",
        all_photos_count:     all_photos_count,
        published_count:      published_count,
        missing_latlon_count: missing_latlon_count,
        missing_factor:       missing_factor,
        css:                  "",
      }
    end

    private def generate_image_url
      return @posts.last.image_url
    end
  end
end
