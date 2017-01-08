class BaseView < Tremolite::Views::BaseView
  def initialize(@blog : Tremolite::Blog, @url : String)
  end

  getter :url

  def to_html
    return top_html +
      head_open_html +
      head_title_html +
      seo_html +
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

  def head_open_html
    # no parameters
    return load_html("include/head_open")
  end

  def head_title_html
    return "<title>#{head_title}</title>\n"
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
    @blog.data_manager.not_nil!["site.desc"]
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

    return load_html("include/nav", h)
  end

  def content
    return ""
  end

  def footer_html
    h = Hash(String, String).new
    h["site.title"] = @blog.data_manager.not_nil!["site.title"] if @blog.data_manager.not_nil!["site.title"]?
    h["year"] = Time.now.year.to_s

    return load_html("include/footer", h)
  end
end

# a little dirty hax
require "./helpers/seo_helper"