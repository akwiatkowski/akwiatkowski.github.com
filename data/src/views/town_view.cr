class TownView < BaseView
  def initialize(@blog : Tremolite::Blog, @town : TownEntity)
    @url = @town.url
  end

  def title
    @town.name
  end

  def content
    town_header_html +
      town_article_html
  end

  def town_header_html
    data = Hash(String, String).new
    data["post.image_url"] = @town.image_url # TODO
    data["post.title"] = @town.name
    data["post.subtitle"] = ""
    return load_html("page/header", data)
  end

  def town_article_html
    content = ""
    data = Hash(String, String).new

    posts = Array(Tremolite::Post).new
    @blog.post_collection.each_post_from_latest do |post|
      if @town.belongs_to_post?(post)
        posts << post
      end
    end

    data["content"] = render_posts_preview(posts)
    return load_html("page/article", data)
  end
end
