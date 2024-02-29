require "./abstract_view"
require "./quant_coord_const"

module GalleryView
  class QuantCoordView < AbstractView
    Log = ::Log.for(self)

    getter :lat, :lon

    def initialize(
      @blog : Tremolite::Blog,
      @key : PhotoCoordQuantCache::PhotoCoordCacheKey,
      @quant_photos : PhotoCoordQuantCache::PhotoCoordCacheArray
    )
      @lat = @key[:lat].as(Float32)
      @lon = @key[:lon].as(Float32)

      @photo_entities = all_published_photo_entities.select do |pe|
        @quant_photos.select do |qp|
          qp[:image_filename] == pe.image_filename &&
            qp[:post_slug] == pe.post_slug
        end.size > 0
      end.as(Array(PhotoEntity))

      @title = "#{@lat} , #{@lon}"
      @url = "/gallery/coord/#{@lat},#{@lon}.html"
      @reverse = true
    end
  end
end
