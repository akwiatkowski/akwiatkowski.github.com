require "./concerns/asset_aware"

class BaseView < Tremolite::Views::BaseView
  include AssetAware

  Log = ::Log.for(self)

  @voivodeship_nav : String?
  @tag_nav : String?
  @lands_nav : String?

  # # Legacy constructor - for backward compatibility during migration
  # def initialize(blog : Tremolite::Blog, @url : String)
  #   super(blog: blog, url: @url)
  # end

  # New constructor - views should use this
  def initialize(context : RenderContext, @url : String)
    super(context: context, url: @url)
  end

  # Get RenderContext - from parent or create lazily from @blog
  def context : RenderContext
    return @context.not_nil! if @context
    @context ||= RenderContext.new(@blog.not_nil!)
  end

  # helper
  def logger
    context.logger
  end

  getter :url

  def to_html
    return top_html +
      head_open_html +
      head_title_html +
      head_canonical_html +
      seo_html +
      open_graph_html +
      tracking_html +
      head_close_html +
      open_body_html +
      nav_html +
      nav_js_overload +
      content +
      footer_html +
      close_body_html +
      close_html_html
  end

  def top_html
    # no parameters
    return load_html("include/top")
  end

  HEAD_OPEN_HTML_KEY = "__html_head"

  # Returns head section with assets loaded based on view's bundle declarations.
  # Uses the asset bundle system to generate appropriate CSS/JS tags.
  #
  # Override asset_bundles, additional_bundles, excluded_bundles, or page_js
  # in subclasses to customize which assets are loaded.
  def head_open_html
    # Build a cache key that includes the resolved bundles
    cache_key = "#{HEAD_OPEN_HTML_KEY}_#{resolved_bundles.join(",")}"

    buffered_html = context.html_buffer.buffer[cache_key]?
    return buffered_html.not_nil! if buffered_html

    context.html_buffer.buffer[cache_key] = String.build do |s|
      s << load_html("include/head_meta")
      s << assets_html(context)
      s << load_html("include/head_icons")
      s << load_html("include/head_feeds")
    end

    context.html_buffer.buffer[cache_key].not_nil!
  end

  def head_title_html
    return "<title>#{head_title}</title>\n"
  end

  def head_canonical_html
    if self.add_to_sitemap?
      # TODO separate canonical and add_to_sitemap?
      return "<link rel=\"canonical\" href=\"#{self.site_url}#{self.url}\" />\n"
    else
      return ""
    end
  end

  def head_title
    # allow validating null titles later
    return "" if title == ""
    return "#{title} - #{site_title}"
  end

  def site_title
    context.site_title
  end

  def site_desc
    context.site_desc
  end

  def site_url
    context.site_url
  end

  private def model_array_to_nav(
    model_array : Array,
    ignore_less_than = 1,
    perform_sort = true,
  )
    nav_array = Array(NamedTuple(
      name: String,
      count: Int32,
      url: String)).new

    model_array.each do |model|
      count = context.post_count_for(model)

      if count >= ignore_less_than
        nav_array << {
          name:  model.name,
          url:   model.view_url,
          count: count,
        }
      end
    end

    if perform_sort
      nav_array = nav_array.sort do |a, b|
        b[:count] <=> a[:count]
      end
    end

    return String.build do |s|
      nav_array.each do |ni|
        h = Hash(String, String).new
        h["url"] = ni[:url]
        h["name"] = "#{ni[:name]} (#{ni[:count]})"

        s << load_html("include/category_nav_element", h)
      end
    end
  end

  def title
    return ""
  end

  def subtitle
    return ""
  end

  def seo_html
    return ""
  end

  def image_url
    return ""
  end

  def open_graph_html
    s = ""
    if image_url != ""
      h = Hash(String, String).new
      h["ol.image"] = site_url + image_url
      s += load_html("include/open_graph_image", h)
    end

    return s
  end

  def tracking_html
    # no parameters
    return load_html("include/tracking")
  end

  def head_close_html
    "</head>\n"
  end

  def open_body_html
    "<body>\n"
  end

  def close_body_html
    "</body>\n"
  end

  def close_html_html
    "</html>\n"
  end

  private def nav_stats_cache
    context.nav_stats_cache
  end

  private def nav_stats_model_array_to_html(
    array,
    key : String,
    include_latest : Bool = false,
  )
    return String.build do |s|
      array.each do |ni|
        h = Hash(String, String).new
        h["url"] = ni.url
        h["name"] = ni.name
        h["id"] = ni.html_id

        s << load_html("include/navigation/category_element", h)
      end

      if include_latest
        h = Hash(String, String).new
        h["url"] = PostListView::NewPostsDynamicView::URL
        h["name"] = "Najnowsze (#{PostListView::NewPostsDynamicView::COUNT})"
        h["id"] = "nav-post-count-tag-latest"

        s << load_html("include/navigation/category_element", h)
      end
    end
  end

  def nav_html
    h = nav_stats_cache.to_hash
    h["site.title"] = context.site_title if context["site.title"]?

    h["nav-voivodeships"] = nav_stats_model_array_to_html(
      array: nav_stats_cache.stats.voivodeships_nav,
      key: "voivodeship"
    )
    h["nav-tags"] = nav_stats_model_array_to_html(
      array: nav_stats_cache.stats.tags_nav,
      include_latest: true,
      key: "tag"
    )
    h["nav-lands"] = nav_stats_model_array_to_html(
      array: nav_stats_cache.stats.lands_nav,
      key: "land"
    )

    return load_html("include/navigation/static", h)
  end

  def nav_js_overload
    # TODO: render js file loading here instead of js script content
    return load_html("include/navigation/js_overload", {} of String => String)
  end

  def content
    return ""
  end

  def footer_html
    h = Hash(String, String).new
    h["site.title"] = context.site_title if context["site.title"]?
    h["year"] = Time.local.year.to_s

    return load_html("include/footer", h)
  end

  # TODO move to include
  def header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = title
    data["post.subtitle"] = subtitle
    return load_html("page/header", data)
  end

  def render_posts_preview(posts : Array(Tremolite::Post))
    content = ""

    posts.each_with_index do |post, i|
      ph = Hash(String, String).new
      ph["post.index_prefix"] = "#{i + 1}. "
      ph["post.url"] = post.url
      ph["post.title"] = post.title
      ph["post.subtitle"] = post.subtitle
      ph["post.date"] = post.date
      ph["post.author"] = post.author
      ph["post.preview-klass"] = ""
      ph["post.additional-info"] = ""

      if post.todo?
        word_count = post.content_html_word_count

        ph["post.preview-klass"] = "post-todo"
        ph["post.additional-info"] = "#{word_count} słów" if word_count > 100
      end

      ph["post.thumb_image_url"] = post.big_thumb_image_url.not_nil!

      content += load_html("post/preview", ph)
      content += "\n"
    end

    return content
  end

  protected def load_js_asset(filename)
    return "<script src=\"/js/#{filename}\" type=\"text/javascript\"></script>\n"
  end
end

# a little dirty hax
require "./helpers/seo_helper"
