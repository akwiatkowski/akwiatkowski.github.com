class Tremolite::Views::BaseView
  def custom_process_function(
    command : String,
    string : String,
    post : (Tremolite::Post | Nil)
  ) : (String | Nil)
    # unescape dash "\_ -> "_
    command = command.gsub(/\"\\_/, "\"_")

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
        image_filename: result[0][1],
        desc: result[0][2],
        param_string: result[0][3]
      )
    end

    # new, w/o string params
    result = command.scan(/photo\s+\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_photo(
        post: post,
        image_filename: result[0][1],
        desc: result[0][2],
        param_string: ""
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

    result = command.scan(/geo\s+([+-]?[0-9]*[.]?[0-9]+),([+-]?[0-9]*[.]?[0-9]+)/)
    if result.size > 0
      return geo_helper(
        lat: result[0][1].to_s.to_f,
        lon: result[0][2].to_s.to_f
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

  def post_photo(post : Tremolite::Post, image_filename : String, desc : String, param_string : String)
    # create entity instance
    photo_entity = PhotoEntity.new(
      post: post,
      desc: desc,
      image_filename: image_filename,
      param_string: param_string
    )

    post.photo_entities.not_nil! << photo_entity

    return post_image(
      photo: photo_entity,
      size: "medium"
    )
  end

  def post_image(photo : PhotoEntity, size : String)
    post_image(
      post: photo.post,
      size: size,
      image_filename: photo.image_filename,
      desc: photo.desc,
      is_gallery: photo.is_gallery,
      is_timeline: photo.is_timeline
    )
  end

  def post_image(
    post : Tremolite::Post,
    size : String,
    image_filename : String,
    desc : String,
    is_gallery : Bool,
    is_timeline : Bool
  )
    url = Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: post.year,
      post_month: post.time.month,
      post_slug: post.slug,
      prefix: size,
      file_name: image_filename
    )

    data = {
      "img.src"           => url,
      "img.alt"           => desc,
      "img.title"         => desc,
      "img.size"          => (image_size(url) / 1024).to_s + " kB",
      "img_full.src"      => "/images/#{post.year}/#{post.slug}/#{image_filename}",
      "img.is_gallery"    => is_gallery.to_s,
      "img.is_timeline"   => is_timeline.to_s
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

  private def geo_helper(lat : Float, lon : Float)
    data = {
      "zoom" => 14.to_s,
      "lat"  => lat.to_s,
      "lon"  => lon.to_s
    }
    # new line could impact markdown processing (ex: list)
    return load_html("partials/geo", data).gsub(/\n/," ")
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
