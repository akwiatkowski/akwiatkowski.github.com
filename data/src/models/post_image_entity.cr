struct PostImageEntity
  @post_slug : String
  @image : String
  @desc : String

  THUMB_PREFIX     = "thumb"
  BIG_THUMB_PREFIX = "big_thumb"
  SMALL_PREFIX     = "small"

  getter :post_slug, :post_year, :post_month, :image, :desc

  def initialize(post, @image, @desc)
    @post_slug = post.slug
    @post_year = post.time.year.as(Int32)
    @post_month = post.time.month.as(Int32)
  end

  def processed_img_path(prefix)
    Tremolite::ImageResizer.processed_path_for_post(
      processed_path: Tremolite::ImageResizer::PROCESSED_IMAGES_PATH_FOR_WEB,
      post_year: post_year,
      post_month: post_month,
      post_slug: post_slug,
      prefix: prefix,
      file_name: image
    )
  end

  def full_image_src
    "/images/#{post_year}/#{post_slug}/#{image}"
  end

  def thumb_image_src
    processed_img_path(THUMB_PREFIX)
  end

  def big_thumb_image_src
    processed_img_path(BIG_THUMB_PREFIX)
  end

  def full_image_size
    0
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.slug == @slug
  end
end
