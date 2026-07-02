class PhotoMapDictionary
  def initialize(
    @output_path : String,
  )
  end

  def get_small_photo_map_for_post(post : Tremolite::Post)
    path = url_photomap_for_post_small(post)
    output_path = File.join([
      @output_path,
      path,
    ])

    if File.exists?(output_path)
      return path
    else
      return nil
    end
  end

  def url_photomap_for_post_big(post : Tremolite::Post)
    return Map::LinkGenerator.url_photomap_for_post_big(post: post)
  end

  def url_photomap_for_post_small(post : Tremolite::Post)
    return Map::LinkGenerator.url_photomap_for_post_small(post: post)
  end
end
