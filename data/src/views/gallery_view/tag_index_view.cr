module GalleryView
  class TagIndexView < PageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @tag_renderers : Array(TagView)
    )
      # ordered only with photos
      @renderers_with_content = @tag_renderers.select do |lr|
        lr.photo_entities_count > 0
      end.sort do |a, b|
        # think it's better to sort by name not count reversed
        # b.photo_entities_count <=> a.photo_entities_count
        a.tag <=> b.tag
      end.as(Array(TagView))

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
      @title = "Tagi"

      @url = "/gallery/tag/"
    end

    getter :image_url, :title, :subtitle, :year, :url

    def inner_html
      return String.build do |s|
        s << "<ul>\n"
        @renderers_with_content.each do |renderer|
          s << "<li>"
          s << "<a href=\"#{renderer.url}\">#{renderer.title}</a> - #{renderer.photo_entities_count}  zdjęć"
          s << "</li>\n"
        end
        s << "</ul>\n"
      end
    end
  end
end
