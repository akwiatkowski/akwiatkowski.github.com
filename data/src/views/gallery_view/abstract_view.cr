require "../wider_page_view"
require "../widest_page_view"

module GalleryView
  class AbstractView < WiderPageView
    Log = ::Log.for(self)

    @reverse : Bool?

    private def data_manager : Tremolite::DataManager
      return @blog.data_manager.not_nil!
    end

    private def posts : Array(Tremolite::Post)
      return @blog.post_collection.posts
    end

    # all but only published
    private def all_published_photo_entities : Array(PhotoEntity)
      return all_published_photo_entities = posts.map { |p|
        p.published_photo_entities
      }.flatten
    end

    private def photo_entities_with_tags(
      all_photos : Array(PhotoEntity) = all_published_photo_entities,
      tags : Array(String) = Array(String).new,
      include_headers : Bool = false,
      fill_until : Int32 = 0,
      limit : Int32? = nil,
    )
      preselected_photos = all_photos.select do |p|
        # filter by tag
        if include_headers == false
          (p.tags & @tags).size > 0
        else
          # header photo should be good enough
          p.is_header || (p.tags & @tags).size > 0
        end
      end

      # fill additional photos when there are no good enough good,best photos
      if preselected_photos.size < fill_until
        # take not included photos, sorted by using super-algorithm
        sorted_photos = (all_photos - preselected_photos).sort do |pa, pb|
          pa.factor_for_gallery_fill <=> pb.factor_for_gallery_fill
        end

        # populate additional
        preselected_photos += sorted_photos[0...(fill_until - preselected_photos.size)]

        # sort
        preselected_photos = preselected_photos.sort
      end

      if limit
        return preselected_photos[0..limit.not_nil!]
      else
        return preselected_photos
      end
    end

    def image_url
      if @photo_entities.size > 0
        return @photo_entities.last.full_image_src.as(String)
      else
        return ""
      end
    end

    getter :title, :url

    def subtitle
      if @photo_entities.size > 0
        return "#{@photo_entities.size} zdjęć od #{@photo_entities.first.time.to_s("%Y-%m-%d")} do #{@photo_entities.last.time.to_s("%Y-%m-%d")}"
      else
        return "brak zdjęć"
      end
    end

    def photo_entities_count
      return @photo_entities.size
    end

    def latest_photo_entity_for_header
      horizontal_pes = @photo_entities.select { |pe| pe.exif.is_horizontal? }
      if horizontal_pes.size > 0
        return horizontal_pes.first
      else
        return @photo_entities.first
      end
    end

    def to_html
      data = Hash(String, String).new
      data["json.items"] = @photo_entities.reverse.map do |photo_entity|
        photo_entity.hash_for_partial
      end.to_json
      data["title"] = title

      return load_html("gallery/gallery_dynamic", data)

      # return top_html +
      #   head_open_html +
      #   title_html +
      #   tracking_html +
      #   head_close_html +
      #   open_body_html +
      #   nav_html +
      #   content +
      #   footer_html +
      #   close_body_html +
      #   close_html_html
    end
  end
end
