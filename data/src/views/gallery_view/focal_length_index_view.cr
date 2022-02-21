module GalleryView
  class FocalLengthIndexView < AbstractIndexView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @renderers : Array(FocalLengthView)
    )
      # ordered only with photos
      @filtered_renderers = @renderers.select do |lr|
        lr.photo_entities_count > 0
      end.sort do |a, b|
        # think it's better to sort by name not count reversed
        # b.photo_entities_count <=> a.photo_entities_count
        a.focal_from <=> b.focal_from
      end.as(Array(FocalLengthView))

      count_sum = @filtered_renderers.map do |lr|
        lr.photo_entities_count
      end.sum

      # TODO this can crash if there is 0 photos
      latest_photo_entity = @filtered_renderers.sort do |a, b|
        a.latest_photo_entity.time <=> b.latest_photo_entity.time
      end.last.latest_photo_entity

      # TODO move to config file
      @image_url = latest_photo_entity.full_image_src.as(String)
      @subtitle = "#{count_sum} zdjęć"
      @title = "Ogniskowe"

      @url = "/gallery/focal_length/"
    end
  end
end
