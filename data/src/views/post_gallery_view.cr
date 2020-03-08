require "../services/exif_stat/exif_stat_helper"
require "./post_gallery_stats_view"

class PostGalleryView < BaseView
  GALLERY_URL_SUFFIX = "/gallery.html"

  def initialize(@blog : Tremolite::Blog, @post : Tremolite::Post)
    @url = @post.url.as(String) + GALLERY_URL_SUFFIX
  end

  # not ready posts will not be added to sitemap.xml
  # this generator is part of `Tremolite` engine
  def ready
    @post.ready?
  end

  def title
    @post.title
  end

  def content
    post_header_html +
      post_article_html
  end

  def post_header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = @post.title
    data["post.subtitle"] = @post.subtitle
    data["post.author"] = @post.author
    data["post.date"] = @post.date
    data["post.date.day_of_week"] = @post.time.day_of_week_polish
    return load_html("post/header", data)
  end

  def image_url
    @post.image_url
  end

  def post_article_html
    data = Hash(String, String).new
    # if not used should be set to blank
    data["next_post_pager"] = ""
    data["prev_post_pager"] = ""

    np = @blog.post_collection.next_to(@post)
    if np
      nd = Hash(String, String).new
      nd["post.url"] = np.url + GALLERY_URL_SUFFIX
      nd["post.title"] = np.title
      nl = load_html("post/pager_next", nd)
      data["next_post_pager"] = nl
    end

    pp = @blog.post_collection.prev_to(@post)
    if pp
      pd = Hash(String, String).new
      pd["post.url"] = pp.url + GALLERY_URL_SUFFIX
      pd["post.title"] = pp.title
      pl = load_html("post/pager_prev", pd)
      data["prev_post_pager"] = pl
    end

    pd = Hash(String, String).new
    pd["post.url"] = @post.url
    pl = load_html("post/pager_post", pd)
    data["post_pager"] = pl

    photo_entities = @post.all_uploaded_photo_entities
    data["photos.count"] = photo_entities.size.to_s

    s = ""
    photo_entities.each do |photo_entity|
      s += load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
    end
    data["content"] = s

    # generate exif based stats and append to gallery page
    data["stats"] = stats_html

    data["stats.path"] = @post.url + PostGalleryStatsView::STATS_URL_SUFFIX

    return load_html("post/gallery", data)
  end

  # overriden here
  def page_desc
    return @post.desc.not_nil!
  end

  # overriden here
  def meta_keywords_string
    return @post.keywords.not_nil!.join(", ").as(String)
  end

  MINIMUM_PHOTOS_FOR_STATS = 5

  # stats for all photos
  def stats_html
    data = Hash(String, String).new

    if @post.all_uploaded_photo_entities.size >= MINIMUM_PHOTOS_FOR_STATS
      # don't render if there is not enough photos
      helper = ExifStatHelper.new(
        posts: [@post],
        photos: @post.all_uploaded_photo_entities
      )
      helper.make_it_so
      return helper.render_post_gallery_stats
    end

    return ""
  end
end
