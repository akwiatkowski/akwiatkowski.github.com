require "../wider_page_view"

module GalleryView
  class AbstractView < WiderPageView
    Log = ::Log.for(self)

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
      fill_until : Int32 = 0
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
        puts "** fill_until #{fill_until}"
        puts "** preselected_photos #{preselected_photos.size}"

        # take not included photos, sorted by using super-algorithm
        sorted_photos = (all_photos - preselected_photos).sort do |pa, pb|
          pa.factor_for_gallery_fill <=> pb.factor_for_gallery_fill
        end

        # populate additional
        preselected_photos += sorted_photos[0...(fill_until - preselected_photos.size)]

        # sort
        preselected_photos = preselected_photos.sort
      end

      return preselected_photos
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

    def latest_photo_entity
      return @photo_entities.first
    end

    # photos will be rendered not within `container` class
    def page_article_html
      return String.build do |s|
        s << photos_html
        s << bottom_html
        s << js_gallery_html
      end
    end

    # in post gallery there are added buttons to next,prev post
    def bottom_html
      return ""
    end

    def inner_html
      return photos
    end

    def photos_html
      return String.build do |s|
        # noticed that `d-inline-flex` remove center align
        # `lg-enabled` enable light gallery for all
        s << "<div class=\"gallery-container flex-wrap lg-enabled\">\n"

        @photo_entities.reverse.each do |photo_entity|
          s << load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
        end

        s << "</div>\n"
      end
    end

    def js_gallery_html
      return "
        <script type=\"text/javascript\">
          $(document).ready(function () {
            galleryMasonry();
          });
        </script>"
    end
  end
end
