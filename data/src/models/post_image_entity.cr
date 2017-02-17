struct PostImageEntity
  @post_slug : String
  @image : String
  @desc : String

  THUMB_PREFIX = "thumb"

  getter :post_slug, :image, :desc

  def initialize(post, @image, @desc)
    @post_slug = post.slug
  end

  def full_image_src
    "/images/#{post_slug}/#{image}"
  end

  def thumb_image_src
    "/images/processed/#{post_slug}_#{THUMB_PREFIX}_#{image}"
  end

  def full_image_size
    0
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.slug == @slug
  end
end
