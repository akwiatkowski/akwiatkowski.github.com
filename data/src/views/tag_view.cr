class TagView < BaseView
  def initialize(@blog : Tremolite::Blog, @tag : TagEntity)
    @url = @tag.url
  end

  def title
    @tag.name
  end

  def content
    tag_header_html +
      tag_article_html
  end

  def tag_header_html
    data = Hash(String, String).new
    data["post.image_url"] = @tag.image_url # TODO
    data["post.title"] = @tag.name
    data["post.subtitle"] = ""
    return load_html("page/header", data)
  end

  def tag_article_html
    content = ""
    data = Hash(String, String).new

    posts = Array(Tremolite::Post).new
    @blog.post_collection.each_post_from_latest do |post|
      if @tag.belongs_to_post?(post)
        posts << post
      end
    end

    data["content"] = render_posts_preview(posts)
    return load_html("page/article", data)
  end
end
