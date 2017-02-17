class GalleryView < PageView
  def initialize(@blog : Tremolite::Blog)
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)
    @post_image_entities = @data_manager.post_image_entities.not_nil!.as(Array(PostImageEntity))

    @image_path = @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["gallery.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["gallery.subtitle"].as(String)

    @url = "/gallery"
  end

  getter :image_path, :title, :subtitle, :year, :url

  def inner_html
    s = ""

    @posts.each do |post|
      images = @post_image_entities.select{|pie| pie.post_slug == post.slug}
      if images.size > 0

        post_images_string = ""
        images.each do |image|
          data = Hash(String, String).new
          data["img_full.src"] = image.full_image_src
          data["img.src"] = image.thumb_image_src
          data["img.alt"] = image.desc
          data["img.size"] = image.full_image_size.to_s
          post_images_string += load_html("gallery/gallery_post_image", data)
        end

        data = Hash(String, String).new
        data["post.title"] = post.title
        data["post.url"] = post.url
        data["post.images"] = post_images_string
        s += load_html("gallery/gallery_post", data)

      end
    end

    return s
  end

end
