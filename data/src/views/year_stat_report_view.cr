class YearStatReportView < PageView
  def initialize(@blog : Tremolite::Blog, @year : Int32)
    @posts = @blog.post_collection.posts.select{|p| p.time.year == @year}.as(Array(Tremolite::Post))
    @image_path = @blog.data_manager.not_nil!["towns.backgrounds"].as(String) # TODO
    @title = "Podsumowanie roku #{@year}"
    @subtitle = "" # TODO
    @url = "/year/#{@year}"
  end

  getter :image_path, :title, :subtitle, :year, :url

  def inner_html
    data = Hash(String, String).new
    data["year"] = @year.to_s
    data["post.count"] = @posts.size.to_i.to_s
    data["hours"] = hours.to_s
    data["distance"] = distance.to_s
    return load_html("year_stat", data)
  end

  private def hours
    return @posts.map{|p| p.time_spent.as(Float64)}.sum
  end

  private def distance
    return @posts.map{|p| p.distance.as(Float64)}.sum
  end


end
