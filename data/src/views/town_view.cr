class TownView < BaseView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @town : TownEntity)
    @url = @town.url

    @posts = Array(Tremolite::Post).new
    @blog.post_collection.each_post_from_latest do |post|
      if @town.belongs_to_post?(post)
        @posts << post
      end
    end
  end

  def title
    @town.name
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

  def image_url_from_geo_coord
    @blog.data_manager.town_photo_cache.not_nil!.get_photo_path_for_town(@town.slug)
  end

  def image_url_from_slug
    return @town.image_url
  end

  def image_url
    # TODO check if results are ok
    temp_image_url = image_url_from_geo_coord
    temp_image_url = image_url_from_slug if temp_image_url.nil?
    return temp_image_url.not_nil!
  end

  def content
    town_header_html +
      town_article_html
  end

  def town_header_html
    data = Hash(String, String).new
    data["post.image_url"] = image_url
    data["post.title"] = @town.name
    data["post.subtitle"] = self.subtitle
    return load_html("page/header", data)
  end

  def town_article_html
    content = ""
    data = Hash(String, String).new

    data["content"] = render_posts_preview(@posts)
    return load_html("page/article", data)
  end
end
