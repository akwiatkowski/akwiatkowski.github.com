# TODO refactor to abstract GalleryAbstractView

# lens showcase
class LensGalleryView < WidePageView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @lens : String, @tags : Array[String] = [])
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # select only photos with proper tag
    photo_entities = @posts.map { |p|
      p.published_photo_entities
    }.flatten

    # tag filtering
    photo_entities = photo_entities.select{ |p|
      (p.tags & @tags).size > 0
    }

    @photo_entities = photo_entities.select { |p|
      p.exif.lens_name == @lens
    }.as(Array(PhotoEntity))

    if @photo_entities.size > 0
      @image_url = @photo_entities.last.full_image_src.as(String)
    else
      @image_url = @data_manager["gallery.lens.image_url"].as(String)
    end

    @title = @lens
    @subtitle = @data_manager["gallery.lens.subtitle"].as(String)

    @lens_sanitized = @lens.gsub(/\s/, "_").downcase.as(String)
    @url = "/gallery/lens/#{@lens_sanitized}"
  end

  getter :image_url, :title, :subtitle, :year, :url

  def inner_html
    return tag_images
  end

  def tag_images
    s = ""

    @photo_entities.each do |photo_entity|
      s += load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
    end

    return s
  end
end
