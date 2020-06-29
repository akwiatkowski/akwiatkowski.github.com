require "./paginated_post_list_view"

class VoivodeshipMasonryView < PostListMasonryView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @voivodeship : VoivodeshipEntity)
    @show_only_count = 8
    @url = @voivodeship.masonry_url

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

  # already added to array in constructor
  def post_list
    @posts
  end
end
