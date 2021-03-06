module GalleryView
  # list of focal length showcase
  class FocalLengthIndexView < PageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @renderers : Array(FocalLengthView)
    )
      # ordered only with photos
      @renderers_with_content = @renderers.select do |lr|
        lr.photo_entities_count > 0
      end.sort do |a, b|
        # think it's better to sort by name not count reversed
        # b.photo_entities_count <=> a.photo_entities_count
        a.focal_from <=> b.focal_from
      end.as(Array(FocalLengthView))

      count_sum = @renderers_with_content.map do |lr|
        lr.photo_entities_count
      end.sum

      # TODO this can crash if there is 0 photos
      latest_photo_entity = @renderers_with_content.sort do |a, b|
        a.latest_photo_entity.time <=> b.latest_photo_entity.time
      end.last.latest_photo_entity

      # TODO move to config file
      @image_url = latest_photo_entity.full_image_src.as(String)
      @subtitle = "#{count_sum} zdjęć"
      @title = "Ogniskowe"

      @url = "/gallery/focal_length/"
    end

    getter :image_url, :title, :subtitle, :year, :url

    def inner_html
      return String.build do |s|
        s << "<ul>\n"
        @renderers_with_content.each do |renderer|
          s << "<li>"
          s << "<a href=\"#{renderer.url}\">#{renderer.title}</a> - #{renderer.photo_entities_count}"
          s << "</li>\n"
        end
        s << "</ul>\n"
      end
    end
  end
end
