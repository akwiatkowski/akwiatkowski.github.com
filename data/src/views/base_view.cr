class BaseView < Tremolite::Views::BaseView
  Log = ::Log.for(self)

  @voivodeship_nav : String?
  @tag_nav : String?

  def initialize(@blog : Tremolite::Blog, @url : String)
  end

  # helper
  def logger
    @blog.logger
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

  # return if cached
  # cache is performed bt HtmlBuffer
  def head_open_html
    buffered_html = @blog.html_buffer.buffer[HEAD_OPEN_HTML_KEY]?
    return buffered_html.not_nil! if buffered_html

    public_path = @blog.@public_path
    i = 0

    original_head = load_html("include/head_open")

    @blog.html_buffer.buffer[HEAD_OPEN_HTML_KEY] = String.build do |s|
      original_head.each_line do |line|
        href_scan_results = line.scan(/href=\"([^"]+)\"/)
        src_scan_results = line.scan(/src=\"([^"]+)\"/)

        (href_scan_results + src_scan_results).each do |scan_result|
          web_path = scan_result[1]
          public_file_path = File.join([public_path, web_path])

          # some included files do not exists
          if File.exists?(public_file_path)
            fi = File.info(public_file_path)
            web_path_with_cache_fix = web_path + "?v=" + fi.modification_time.to_unix.to_s

            line = line.gsub(web_path, web_path_with_cache_fix)

            i += 1
          else
            Log.error { "#{web_path} assets NOT exists!" }
          end
        end

        s << line
        s << "\n"
      end
    end

    Log.debug { "#{i} added cache fix for assets" }

    return @blog.html_buffer.buffer[HEAD_OPEN_HTML_KEY]?.not_nil!
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
    @blog.data_manager.not_nil!["site.title"]
  end

  def site_desc
    @blog.renderer.site_desc
  end

  def site_url
    @blog.data_manager.not_nil!["site.url"]
  end

  private def model_array_to_nav(
    model_array : Array,
    ignore_less_than = 1
  )
    nav_array = Array(NamedTuple(
      name: String,
      count: Int32,
      url: String)).new

    model_array.each do |model|
      count = @blog.post_collection.posts.select { |post| post.was_in?(model) && post.ready? }.size

      if count >= ignore_less_than
        nav_array << {
          name:  model.name,
          url:   model.masonry_url,
          count: count,
        }
      end
    end

    nav_array = nav_array.sort do |a, b|
      b[:count] <=> a[:count]
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

  # cached list of voivodeship links for nav
  def voivodeship_nav
    if @voivodeship_nav.nil?
      if @voivodeship_nav.nil?
        voivodeships = @blog.data_manager.voivodeships.not_nil!
        @voivodeship_nav = model_array_to_nav(
          model_array: voivodeships,
          ignore_less_than: 2
        ).as(String)
      end
    end

    return @voivodeship_nav.not_nil!
  end

  # cached list of lands links for nav
  def lands_nav
    if @lands_nav.nil?
      lands = @blog.data_manager.lands.not_nil!
      @lands_nav = model_array_to_nav(
        model_array: lands,
        ignore_less_than: 4
      ).as(String)
    end

    return @lands_nav.not_nil!
  end

  # cached list of tags links for nav
  def tag_nav
    if @tags_nav.nil?
      tags = @blog.data_manager.tags.not_nil!
      @tags_nav = model_array_to_nav(
        model_array: tags,
        ignore_less_than: 2
      ).as(String)
    end

    return @tags_nav.not_nil!
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

  def nav_html
    # parametrized
    h = Hash(String, String).new
    h["site.title"] = @blog.data_manager.not_nil!["site.title"] if @blog.data_manager.not_nil!["site.title"]?
    h["nav-voivodeships"] = voivodeship_nav
    h["nav-tags"] = tag_nav
    h["nav-lands"] = lands_nav

    return load_html("include/nav", h)
  end

  def content
    return ""
  end

  def footer_html
    h = Hash(String, String).new
    h["site.title"] = @blog.data_manager.not_nil!["site.title"] if @blog.data_manager.not_nil!["site.title"]?
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
end

# a little dirty hax
require "./helpers/seo_helper"
