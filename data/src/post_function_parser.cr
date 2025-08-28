class Tremolite::Views::BaseView
  PHOTO_COMMAND        = "photo"
  HEADER_PHOTO_COMMAND = "photo_header"

  def custom_process_function(
    command : String,
    string : String,
    post : (Tremolite::Post | Nil),
  ) : (String | Nil)
    # unescape dash "\_ -> "_
    command = command.gsub(/\"\\_/, "\"_")

    result = command.scan(/current_year/)
    if result.size > 0
      return Time.local.year.to_s
    end

    result = command.scan(/pro_tip/)
    if result.size > 0
      return pro_tip(post)
    end

    # new, with string params
    result = command.scan(/#{PHOTO_COMMAND}\s+\"([^\"]+)\"\s*,\s*\"([^\"]+)\"\s*,\s*\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_photo(
        post: post,
        image_filename: result[0][1],
        desc: result[0][2],
        param_string: result[0][3]
      )
    end

    # new, w/o string params
    result = command.scan(/#{PHOTO_COMMAND}\s+\"([^\"]+)\"\s*,\s*\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_photo(
        post: post,
        image_filename: result[0][1],
        desc: result[0][2],
        param_string: ""
      )
    end

    # header photo command - add title, tags
    # used for creating portfolio page
    result = command.scan(/#{HEADER_PHOTO_COMMAND}\s+\"([^\"]+)\"\s*,\s*\"([^\"]*)\"/)
    if result.size > 0 && post
      return header_post_photo_attrs(
        post: post,
        desc: result[0][1],
        param_string: result[0][2]
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

  # used to update header
  def header_post_photo_attrs(post : Tremolite::Post, desc : String, param_string : String)
    post.update_photo_header_desc_and_params(desc, param_string)

    return ""
  end

  def self.bootstrap_icon(key : String, size : Int32 = 16)
    String.build do |s|
      s << "<svg class=\"bi\" width=\"#{size}\" height=\"#{size}\" fill=\"currentColor\">"
      s << "\t<use xlink:href=\"/icons/bootstrap-icons.svg##{key}\"/>"
      s << "</svg>"
    end
  end

  def post_photo(post : Tremolite::Post, image_filename : String, desc : String, param_string : String)
    # create entity instance
    photo_entity = PhotoEntity.new(
      post: post,
      desc: desc,
      image_filename: image_filename,
      param_string: param_string,
    )

    # add to list, fetch exif or get exif cache, set some attribs
    exifed_pe = @blog.data_manager.exif_db.append_published_photo_entity(photo_entity)

    return post_image(
      photo: exifed_pe,
      size: "medium"
    )
  end

  def self.photo_tag_gallery_link(photo_entity, tag)
    String.build do |s|
      s << "<a href=\"/gallery/#{tag}##{photo_entity.full_image_sanitized}\">"
      s << bootstrap_icon(
        key: PhotoEntity::TAG_BOOTSTRAP_ICON[tag],
        size: 16
      )
      s << "</a> "
    end
  end

  def post_image(photo : PhotoEntity, size : String)
    tag_galleries_link = String.build do |s|
      # only predefined tags will have icon link to gallery page
      PhotoEntity::TAG_BOOTSTRAP_ICON.keys.each do |tag|
        if photo.tags.includes?(tag)
          s << self.class.photo_tag_gallery_link(
            photo_entity: photo,
            tag: tag
          )
        end
      end
    end

    post_image(
      post_time: photo.post_time,
      post_slug: photo.post_slug,
      size: size,
      image_filename: photo.image_filename,
      desc: photo.desc,
      is_gallery: photo.is_gallery,
      is_timeline: photo.is_timeline,
      exif: photo.exif,
      additional_links: tag_galleries_link,
      photo_entity: photo
    )
  end

  def post_image(
    post_time : Time,
    post_slug : String,
    size : String,
    image_filename : String,
    desc : String,
    is_gallery : Bool,
    is_timeline : Bool,
    exif : (ExifEntity | Nil),
    additional_links : String? = nil,
    photo_entity : PhotoEntity? = nil,
  )
    url = Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: post_time.year,
      post_month: post_time.month,
      post_slug: post_slug,
      prefix: size,
      file_name: image_filename
    )

    if exif
      exif_string = exif.not_nil!.exif_string
    else
      exif_string = ""
    end

    data = {
      "img.src"              => url,
      "img.alt"              => desc,
      "img.title"            => desc,
      "img.size"             => (image_size(url) / 1024).to_s + " kB",
      "img_full.src"         => "/images/#{post_time.year}/#{post_slug}/#{image_filename}",
      "img.is_gallery"       => is_gallery.to_s,
      "img.is_timeline"      => is_timeline.to_s,
      "img.lat"              => "",
      "img.lon"              => "",
      "img.altitude"         => "",
      "img.time"             => "",
      "img.exif_string"      => exif_string,
      "img.additional_links" => additional_links.to_s,

      "img.coord_link" => link_to_gallery_coord_for_photo(photo_entity),
    }

    if exif
      data.merge!(exif.not_nil!.hash_for_partial)
    end

    return load_html("post/post_image_partial", data)
  end

  def link_to_gallery_coord_for_photo(photo_entity, min_count = 2)
    return String.build do |s|
      next if photo_entity.nil?
      next if photo_entity.exif.lat.nil?
      next if photo_entity.exif.lon.nil?

      data_manager = @blog.data_manager.not_nil!
      photo_coord_quant_cache = data_manager.photo_coord_quant_cache.not_nil!
      array = photo_coord_quant_cache.get(photo_entity.not_nil!)

      if array && array.not_nil!.size > min_count
        key = photo_coord_quant_cache.convert_photo_entity_to_key(photo_entity.not_nil!)
        link = "/gallery/coord/#{key[:lat]},#{key[:lon]}"
        s << " <a href=\"#{link}\" target=\"_blank\">okolica</a>\n"
      end
    end
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
      "lon"  => lon.to_s,
    }
    # new line could impact markdown processing (ex: list)
    return load_html("partials/geo", data).gsub(/\n/, " ")
  end

  private def pro_tip(post : (Tremolite::Post | Nil))
    return load_html("partials/pro_tip")
  end

  def public_path
    @blog.public_path.as(String)
  end

  def image_size(url)
    path = File.join([public_path, url])
    if File.exists?(path)
      return File.size(path)
    else
      return 0
    end
  end
end
