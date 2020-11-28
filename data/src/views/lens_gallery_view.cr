# TODO refactor to abstract GalleryAbstractView

# lens showcase
class LensGalleryView < WidePageView
  Log = ::Log.for(self)

  def initialize(
    @blog : Tremolite::Blog,
    @lens : String,
    @tags : Array(String) = Array(String).new,
    @include_headers : Bool = false
  )
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # select only photos with proper tag
    all_photo_entities = @posts.map { |p|
      p.published_photo_entities
    }.flatten

    # tag filtering
    photo_entities = all_photo_entities.select{ |p|
      if @include_headers
        (p.tags & @tags).size > 0
      else
        # header photo should be good enough
        p.is_header || (p.tags & @tags).size > 0
      end
    }

    @photo_entities = photo_entities.select { |p|
      p.exif.lens_name == @lens
    }.as(Array(PhotoEntity))

    if @photo_entities.size > 0
      @image_url = @photo_entities.last.full_image_src.as(String)
      @subtitle = "#{@photo_entities.size} zdjęć od #{@photo_entities.first.time.to_s("%Y-%m-%d")} do #{@photo_entities.last.time.to_s("%Y-%m-%d")}"
    else
      @image_url = @data_manager["gallery.lens.backgrounds"].as(String)
      @subtitle = "brak zdjęć"
    end

    @title = @lens

    @lens_sanitized = @lens.gsub(/\s/, "_").downcase.as(String)
    @url = "/gallery/lens/#{@lens_sanitized}"
  end

  getter :image_url, :title, :subtitle, :year, :url

  def photo_entities_count
    return @photo_entities.size
  end

  def latest_photo_entity
    return @photo_entities.first
  end

  def inner_html
    return tag_images
  end

  def tag_images
    s = ""

    @photo_entities.reverse.each do |photo_entity|
      s += load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
    end

    return s
  end
end
