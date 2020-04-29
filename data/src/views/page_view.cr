class PageView < BaseView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @url : String)
  end

  def image_url
    ""
  end

  def title
    ""
  end

  def subtitle
    ""
  end

  def inner_html
    ""
  end

  def content
    page_header_html +
      page_article_html
  end

  def page_header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = title
    data["post.subtitle"] = subtitle
    return load_html("page/header", data)
  end

  def page_article_html
    data = Hash(String, String).new
    data["content"] = inner_html
    return load_html("page/article", data)
  end

  # same as `page_article_html` but for not pure text articles
  # margins are much smaller
  def page_article_full_wide_html
    data = Hash(String, String).new
    data["content"] = inner_html
    return load_html("page/article_full_wide", data)
  end

  # override layout for photo only view
  def page_article_wide_html
    data = Hash(String, String).new
    data["content"] = inner_html
    return load_html("page/article_wider", data)
  end
end
