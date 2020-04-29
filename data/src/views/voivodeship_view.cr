class VoivodeshipView < BaseView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @voivodeship : VoivodeshipEntity)
    @url = @voivodeship.url

    @posts = Array(Tremolite::Post).new
    @blog.post_collection.each_post_from_latest do |post|
      if @voivodeship.belongs_to_post?(post)
        @posts << post
      end
    end
  end

  def title
    @voivodeship.name
  end

  def subtitle
    s = @posts.size
    return case s
    when 0       then "brak wpisów"
    when 1       then "1 wpis"
    when 2, 3, 4 then "#{s} wpisy, między #{time_range_string}"
    else              "#{s} wpisów, między #{time_range_string}"
    end
  end

  def time_range_string
    if @posts.size > 1
      return "#{@posts.first.date} - #{@posts.last.date}"
    else
      return ""
    end
  end

  def image_url
    return @voivodeship.image_url
  end

  def content
    voivodeship_header_html +
      voivodeship_article_html
  end

  def voivodeship_header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = @voivodeship.name
    data["post.subtitle"] = self.subtitle
    return load_html("page/header", data)
  end

  def voivodeship_article_html
    content = ""
    data = Hash(String, String).new

    data["content"] = render_posts_preview(@posts)
    return load_html("page/article", data)
  end
end
