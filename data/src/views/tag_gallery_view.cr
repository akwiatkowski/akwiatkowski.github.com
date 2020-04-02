# TODO refactor to abstract GalleryAbstractView
class TagGalleryView < WidePageView
  def initialize(@blog : Tremolite::Blog, @tag : String)
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # select only photos with proper tag
    @photo_entities = @posts.map { |p|
      p.published_photo_entities
    }.flatten.select { |p|
      p.tags.includes?(@tag)
    }.as(Array(PhotoEntity))

    @image_url = @data_manager["gallery.#{@tag}.backgrounds"].as(String)
    @title = @data_manager["gallery.#{@tag}.title"].as(String)
    @subtitle = @data_manager["gallery.#{@tag}.subtitle"].as(String)

    @url = "/gallery/#{@tag}"
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
