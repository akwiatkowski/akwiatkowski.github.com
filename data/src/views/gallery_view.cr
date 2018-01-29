class GalleryView < PageView
  def initialize(@blog : Tremolite::Blog)
    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    @selected_posts = @posts.select { |a| a.nogallery.not_nil! != true }.as(Array(Tremolite::Post))
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)
    @post_image_entities = @data_manager.post_image_entities.not_nil!.as(Array(PostImageEntity))

    @image_url = @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["gallery.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["gallery.subtitle"].as(String)

    @url = "/gallery"
  end

  getter :image_url, :title, :subtitle, :year, :url

  def inner_html
    s = ""

    sorted_by_time = @selected_posts.sort { |a, b| a.time <=> b.time }
    if sorted_by_time.size > 0
      time_from = sorted_by_time.first.time
      time_to = sorted_by_time.last.time

      t = time_to.at_end_of_month

      # month loop
      while t > time_from
        # month header
        data = Hash(String, String).new
        data["month_string"] = t.to_s("%Y-%m")
        month_header = load_html("gallery/gallery_month_separator", data)
        # some processing
        posts_in_month = @posts.select { |p| p.time >= t.at_beginning_of_month && p.time < t.at_end_of_month }.sort { |a, b| b.time <=> a.time }
        # not add empty months
        s += month_header if posts_in_month.size > 0

        # content
        if posts_in_month.size > 0
          posts_in_month.each do |post|
            s += post_images(post)
          end
        end

        # to be sure
        t = t.at_beginning_of_month - Time::Span.new(24, 0, 0)
      end
    end

    return s
  end

  def post_images(post)
    s = ""

    data = Hash(String, String).new
    data["klass"] = "gallery-header-image"
    data["post.url"] = post.url
    data["img.src"] = post.big_thumb_image_url.not_nil!
    data["img.alt"] = post.title
    data["post.title"] = post.title
    data["img.url"] = post.image_url
    data["img.size"] = "" # TODO
    s += load_html("gallery/gallery_post_image", data)

    post_images_string = ""
    images = @post_image_entities.select { |pie| pie.post_slug == post.slug }
    images.each do |image|
      data = Hash(String, String).new
      data["klass"] = "gallery-regular-image"
      data["post.url"] = post.url
      data["img.src"] = image.big_thumb_image_src
      data["img.alt"] = image.desc
      data["img.size"] = image.full_image_size.to_s
      data["post.title"] = post.title
      data["img.url"] = image.full_image_src
      s += load_html("gallery/gallery_post_image", data)
    end

    return s
  end
end
