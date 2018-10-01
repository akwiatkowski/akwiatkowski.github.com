class Tremolite::Views::BaseView
  def custom_process_function(
    command : String,
    string : String,
    post : (Tremolite::Post | Nil)
  ) : (String | Nil)
    result = command.scan(/current_year/)
    if result.size > 0
      return Time.now.year.to_s
    end

    result = command.scan(/pro_tip/)
    if result.size > 0
      return pro_tip(post)
    end

    # new, with string params
    result = command.scan(/photo\s+\"([^\"]+)\",\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_photo(
        post: post,
        image: result[0][1],
        alt: result[0][2],
        param_string: result[0][3]
      )
    end

    # new, w/o string params
    result = command.scan(/photo\s+\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_photo(
        post: post,
        image: result[0][1],
        alt: result[0][2],
        param_string: ""
      )
    end

    # basic with size
    result = command.scan(/post_image\s+\"([^\"]+)\",\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_image(
        post: post,
        size: result[0][1],
        image: result[0][2],
        alt: result[0][3],
        gallery: true
      )
    end

    # deprecated
    result = command.scan(/post_image_no_gallery\s+\"([^\"]+)\",\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_image(
        post: post,
        size: result[0][1],
        image: result[0][2],
        alt: result[0][3],
        gallery: false
      )
    end

    result = command.scan(/strava_iframe\s+\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0
      return strava_iframe(
        activity_id: result[0][1], # faster to use String all the time
        token: result[0][2].to_s
      )
    end

    result = command.scan(/vimeo_iframe\s+\"([^\"]+)\"/)
    if result.size > 0
      return vimeo_iframe(
        vimeo_id: result[0][1]
      )
    end

    result = command.scan(/todo/)
    if result.size > 0 && post
      return todo_mark(
        post: post
      )
    end

    return nil
  end

  FLAG_NOGALLERY = "nogallery"

  def post_photo(post : Tremolite::Post, image : String, alt : String, param_string : String)
    gallery = true

    if param_string.includes?(FLAG_NOGALLERY)
      gallery = false
    end

    return post_image(
      post: post,
      size: "medium",
      image: image,
      alt: alt,
      gallery: gallery
    )
  end

  def post_image(post : Tremolite::Post, size : String, image : String, alt : String, gallery : Bool)
    url = Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: post.year,
      post_month: post.time.month,
      post_slug: post.slug,
      prefix: size,
      file_name: image
    )

    add_post_photo_to_gallery(post: post, image: image, desc: alt) if gallery
    data = {
      "img.src"           => url,
      "img.alt"           => alt,
      "img.size"          => (image_size(url) / 1024).to_s + " kB",
      "img_full.src"      => "/images/#{post.year}/#{post.slug}/#{image}",
      "img.is_in_gallery" => gallery.to_s,
    }
    return load_html("post/post_image_partial", data)
  end

  def strava_iframe(activity_id : String, token : String)
    data = {
      "strava.activity_id" => activity_id,
      "strava.token"       => token,
    }
    return load_html("partials/strava_iframe", data)
  end

  def vimeo_iframe(vimeo_id : String)
    data = {
      "vimeo.id" => vimeo_id,
    }
    return load_html("partials/vimeo_iframe", data)
  end

  private def todo_mark(post : Tremolite::Post)
    # TODO add to some kind of dynamic list of todos
    return "" # to not render it
  end

  private def add_post_photo_to_gallery(post : Tremolite::Post, image : String, desc : String)
    @blog.data_manager.not_nil!.add_post_image_entity(
      post: post,
      desc: desc,
      image: image
    )
  end

  private def pro_tip(post : (Tremolite::Post | Nil))
    return load_html("partials/pro_tip")
  end

  def public_path
    @blog.public_path.as(String)
  end

  def image_size(url)
    File.size(File.join([public_path, url]))
  end
end
