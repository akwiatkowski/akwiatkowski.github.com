module GalleryView
  # list of lens showcase
  class LensIndexView < AbstractIndexView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @renderers : Array(LensView),
    )
      # ordered only with photos
      @filtered_renderers = @renderers.select do |lr|
        lr.photo_entities_count > 0
      end.sort do |a, b|
        # think it's better to sort by name not count reversed
        # b.photo_entities_count <=> a.photo_entities_count
        a.title <=> b.title
      end.uniq do |lr|
        # there was problem with doubled viewers because of
        # multiple kind of "misc" lenses
        lr.url
      end.as(Array(LensView))

      count_sum = @filtered_renderers.map do |lr|
        lr.photo_entities_count
      end.sum

      # TODO this can crash if there is 0 photos
      latest_photo_entity_for_header = @filtered_renderers.sort do |a, b|
        a.latest_photo_entity_for_header.time <=> b.latest_photo_entity_for_header.time
      end.last.latest_photo_entity_for_header

      # TODO move to config file
      @image_url = latest_photo_entity_for_header.full_image_src.as(String)
      @subtitle = "#{count_sum} zdjęć"
      @title = "Obiektywy"

      @url = "/gallery/lens/"
    end
  end
end
