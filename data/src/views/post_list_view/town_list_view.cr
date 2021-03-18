require "./abstract_list_view"

module PostListView
  class TownListView < AbstractListView
    Log = ::Log.for(self)

    @preselected_size : Int32?

    def initialize(@blog : Tremolite::Blog, @town : TownEntity)
      @url = @town.list_url

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @town.belongs_to_post?(post)
          @posts << post
        end
      end

      @photo_cache = @blog.data_manager.town_photo_cache.not_nil!.get_cache_structure(@town.slug).as(TownPhotoCache::TownPhotoCacheData?)
      if @photo_cache
        @preselected_size = @photo_cache.not_nil![:preselected_size]
      else
        @preselected_size = nil
      end
    end

    def title
      @town.name
    end

    def image_url_from_geo_coord
      if @photo_cache
        return @photo_cache.not_nil![:photo_path].not_nil!
      end
    end

    def image_url_from_slug
      return @town.image_url
    end

    def image_url
      # TODO check if results are ok
      temp_image_url = image_url_from_geo_coord
      temp_image_url = image_url_from_slug if temp_image_url.nil?
      return temp_image_url.not_nil!
    end

  end
end
