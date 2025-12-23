require "./abstract_view"
require "./quant_coord_const"

module GalleryView
  class QuantCoordView < AbstractView
    Log = ::Log.for(self)

    getter :lat, :lon, :closest_town_distance, :closest_town_name,
      :photo_entities

    def initialize(
      @blog : Tremolite::Blog,
      @key : PhotoCoordQuantCache::PhotoCoordCacheKey,
      @quant_photos : PhotoCoordQuantCache::PhotoCoordCacheArray,
      @quant_info : PhotoCoordQuantCache::PhotoCoordCacheAdditionalInfo,
    )
      @lat = @key[:lat].as(Float32)
      @lon = @key[:lon].as(Float32)

      @closest_town_distance = @quant_info[:closest_town_distance].as(Float32)
      @closest_town_name = @quant_info[:closest_town_name].as(String?)

      @photo_entities = all_published_photo_entities.select do |pe|
        @quant_photos.select do |qp|
          qp[:image_filename] == pe.image_filename &&
            qp[:post_slug] == pe.post_slug
        end.size > 0
      end.as(Array(PhotoEntity))

      if @closest_town_distance.to_i > 20
        town_name_text = " - #{@closest_town_distance.to_i}km od #{@closest_town_name}"
      elsif @closest_town_distance.to_i > 100
        town_name_text = ""
      else
        town_name_text = " - #{@closest_town_name}"
      end

      @title = "#{@lat},#{@lon}#{town_name_text}"
      @url = "/galeria/wspolrzedne/#{@lat},#{@lon}.html"
      @reverse = true
    end
  end
end
