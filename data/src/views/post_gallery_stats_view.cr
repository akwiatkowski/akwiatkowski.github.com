require "../services/exif_stat/exif_stat_helper"

class PostGalleryStatsView < BaseView
  STATS_URL_SUFFIX = "/gallery_stats.html"

  def initialize(@blog : Tremolite::Blog, @post : Tremolite::Post)
    @url = @post.url.as(String) + STATS_URL_SUFFIX
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
      nd["post.url"] = np.url + STATS_URL_SUFFIX
      nd["post.title"] = np.title
      nl = load_html("post/pager_next", nd)
      data["next_post_pager"] = nl
    end

    pp = @blog.post_collection.prev_to(@post)
    if pp
      pd = Hash(String, String).new
      pd["post.url"] = pp.url + STATS_URL_SUFFIX
      pd["post.title"] = pp.title
      pl = load_html("post/pager_prev", pd)
      data["prev_post_pager"] = pl
    end

    pd = Hash(String, String).new
    pd["post.url"] = @post.url
    pl = load_html("post/pager_post", pd)
    data["post_pager"] = pl

    data["content_for_published"] = stats_for_published_photos
    data["content_for_all"] = stats_for_all_photos

    return load_html("post/gallery_stats", data)
  end

  def stats_for_published_photos
    helper = ExifStatHelper.new(
      posts: [@post],
      photos: @post.photo_entities.not_nil!
    )
    helper.make_it_so

    return helper.render_post_gallery_detailed_stats
  end

  def stats_for_all_photos
    helper = ExifStatHelper.new(
      posts: [@post],
      photos: @post.all_uploaded_photo_entities
    )
    helper.make_it_so
    return helper.render_post_gallery_detailed_stats
  end
end
