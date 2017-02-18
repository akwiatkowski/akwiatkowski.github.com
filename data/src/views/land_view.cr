class LandView < BaseView
  def initialize(@blog : Tremolite::Blog, @land : LandEntity)
    @url = @land.url
  end

  def title
    @land.name
  end

  def image_url
    return @land.image_url
  end

  def content
    land_header_html +
      land_article_html
  end

  def land_header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = @land.name
    data["post.subtitle"] = @land.main
    return load_html("page/header", data)
  end

  def land_article_html
    content = ""
    data = Hash(String, String).new

    posts = Array(Tremolite::Post).new
    @blog.post_collection.each_post_from_latest do |post|
      if @land.belongs_to_post?(post)
        posts << post
      end
    end

    data["content"] = render_posts_preview(posts)
    return load_html("page/article", data)
  end
end
