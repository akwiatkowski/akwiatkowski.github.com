class PhotoMapDictionary
  def initialize(
    @public_path : String
  )
  end

  def get_small_photo_map_for_post(post : Tremolite::Post)
    path = url_photomap_for_post_small(post)
    public_path = File.join([
      @public_path,
      path,
    ])

    if File.exists?(public_path)
      return path
    else
      return nil
    end
  end

  def url_photomap_for_post_big(post : Tremolite::Post)
    return "/photo_map/for_post/#{post.slug}/big.svg"
  end

  def url_photomap_for_post_small(post : Tremolite::Post)
    return "/photo_map/for_post/#{post.slug}/small.svg"
  end
end
