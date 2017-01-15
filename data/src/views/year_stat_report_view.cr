class YearStatReportView < PageView
  def initialize(@blog : Tremolite::Blog, @year : Int32)
    @posts = @blog.post_collection.posts.select{|p| p.time.year == @year}.as(Array(Tremolite::Post))
    @image_path = generate_image_url.as(String)
    @title = "#{@year}"
    @subtitle = "Podsumowanie roku #{@year}"
    @url = "/year/#{@year}"
  end

  getter :image_path, :title, :subtitle, :year, :url

  def inner_html
    data = Hash(String, String).new
    data["year"] = @year.to_s
    data["post.count"] = @posts.size.to_i.to_s

    data["hours"] = hours.to_i.to_s
    data["distance"] = distance.to_i.to_s

    data["bicycle_distance"] = bibycle_distance.to_i.to_s
    data["bicycle_hours"] = bicycle_hours.to_i.to_s

    data["voivodeships_stats"] = voivodeships_stats.inspect #.sort
    return load_html("year_stat", data)
  end

  private def hours
    return @posts.map{|p| p.time_spent.as(Float64)}.sum
  end

  private def distance
    return @posts.map{|p| p.distance.as(Float64)}.sum
  end

  private def voivodeships_stats
    voivoids = @blog.data_manager.not_nil!.voivodeships.not_nil!
    d = Hash(String, Int32).new
    @posts.each do |post|
      vs = post.towns.not_nil!.select{|t| voivoids.map(&.slug).includes?(t) }
      vs.each do |v|
        if d[v]?
          d[v] += 1
        else
          d[v] = 1
        end
      end
    end

    return d
  end

  BICYCLE_TAG = "bicycle"

  private def bibycle_distance
    return @posts.select{|p| p.tags.not_nil!.includes?(BICYCLE_TAG)}.map{|p| p.distance.as(Float64)}.sum
  end

  private def bicycle_hours
    return @posts.select{|p| p.tags.not_nil!.includes?(BICYCLE_TAG)}.map{|p| p.time_spent.as(Float64)}.sum
  end

  private def generate_image_url
    return @posts.select{|p| true }.sort{ |a,b|
      b.distance.not_nil! <=> a.distance.not_nil!
    }.first.image_url
  end

end
