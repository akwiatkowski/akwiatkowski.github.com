class GalleryAbstractView < WiderPageView
  Log = ::Log.for(self)

  private def data_manager : Tremolite::DataManager
    return @blog.data_manager.not_nil!
  end

  private def posts : Array(Tremolite::Post)
    return @blog.post_collection.posts
  end

  # all but only published
  private def all_photo_entities : Array(PhotoEntity)
    return all_photo_entities = posts.map { |p|
      p.published_photo_entities
    }.flatten
  end

  private def photo_entities_with_tags(
    tags : Array(String),
    include_headers : Bool = false
  )
    photo_entities = all_photo_entities.select { |p|
      if include_headers == false
        (p.tags & @tags).size > 0
      else
        # header photo should be good enough
        p.is_header || (p.tags & @tags).size > 0
      end
    }
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

  def inner_html
    return photos
  end

  def photos
    return String.build do |s|
      s << "<div class=\"gallery-container\">\n"

      @photo_entities.reverse.each do |photo_entity|
        s << load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
      end

      s << "</div>\n"
    end
  end

  # an example of code, can be out of date
  # def initialize(
  #   @blog : Tremolite::Blog,
  #   @lens : String,
  #   @tags : Array(String) = Array(String).new,
  #   @include_headers : Bool = false
  # )
  #
  #   @photo_entities = photo_entities_with_tags(@tags, @include_headers).select do |p|
  #     p.exif.lens_name == @lens
  #   end.as(Array(PhotoEntity))
  #
  #   @title = @lens
  #   @lens_sanitized = @lens.gsub(/\s/, "_").downcase.as(String)
  #   @url = "/gallery/lens/#{@lens_sanitized}"
  # end
end
