require "./abstract_view"

module GalleryView
  class PostView < AbstractView
    Log = ::Log.for(self)

    GALLERY_URL_SUFFIX = "/gallery.html"

    def initialize(@blog : Tremolite::Blog, @post : Tremolite::Post)
      @photo_entities = @post.all_photo_entities_sorted.as(Array(PhotoEntity))
      @title = @post.title.as(String)
      @subtitle = @post.subtitle.as(String)
      @url = @post.url.as(String) + GALLERY_URL_SUFFIX
      @reverse = false
    end

    def page_desc
      return @post.desc.not_nil!
    end

    def meta_keywords_string
      return @post.keywords.not_nil!.join(", ").as(String)
    end

    def image_url
      @post.image_url
    end

    def add_to_sitemap?
      return false
    end

    def ready
      @post.ready?
    end

    def subtitle
      return @subtitle
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

    def bottom_html
      data = Hash(String, String).new
      data["post.slug"] = @post.slug
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

      data["stats.path"] = @post.url + PostGalleryStatsView::STATS_URL_SUFFIX

      return load_html("post/gallery_bottom", data)
    end
  end
end
