class YearStatReportView < PageView
  def initialize(@blog : Tremolite::Blog,
                 @year : Int32,
                 @all_years : Array(Int32))
    @posts = @blog.post_collection.posts.select { |p| p.time.year == @year }.as(Array(Tremolite::Post))
    @image_url = generate_image_url.as(String)
    @title = "#{@year}"
    @subtitle = "Podsumowanie roku #{@year}"

    # if Time.now.year == @year
    #   @url = "/year/current"
    # else
    #   @url = "/year/#{@year}"
    # end
    @url = "/year/#{@year}"
  end

  getter :image_url, :title, :subtitle, :year
  property :url

  def inner_html
    data = Hash(String, String).new
    data["year"] = @year.to_s
    data["post.count"] = @posts.size.to_i.to_s

    data["hours"] = hours.to_i.to_s
    data["distance"] = distance.to_i.to_s

    data["bicycle_distance"] = bibycle_distance.to_i.to_s
    data["bicycle_hours"] = bicycle_hours.to_i.to_s

    voivodeships_stats_strings = Array(String).new
    voivodeships_stats.keys.each do |k|
      voivodeships_stats_strings << "#{k} - #{voivodeships_stats[k]}"
    end
    data["voivodeships_stats"] = voivodeships_stats_strings.join(", ")

    years_strings = Array(String).new
    @all_years.each do |y|
      if @year != y
        years_strings << "<a href=\"/year/#{y}\">#{y}</a>"
      else
        years_strings << "<strong>#{y}</strong>"
      end
    end
    data["other_year_links"] = years_strings.join(", ")

    posts_list = "<ul>\n"
    @posts.each do |post|
      post_data = Hash(String, String).new
      post_data["post.date"] = post.date
      post_data["post.title"] = post.title
      post_data["post.url"] = post.url

      post_distance = post.distance.as(Float64).ceil.to_i
      if post_distance > 0
        post_data["post.distance"] = post_distance.to_s
      else
        post_data["post.distance"] = ""
      end

      post_time_spent = post.time_spent.as(Float64).ceil.to_i
      if post_time_spent > 0
        post_data["post.time_spent"] = post_time_spent.to_s
      else
        post_data["post.time_spent"] = ""
      end

      if post.bicycle?
        activity_icon_class = "icon-bicycle"
      elsif post.hike? && post_distance > 0
        activity_icon_class = "icon-hike"
      elsif post.train?
        activity_icon_class = "icon-train"
      elsif post.car?
        activity_icon_class = "icon-car"
      elsif post.walk?
        activity_icon_class = "icon-walk"
      else
        activity_icon_class = ""
      end
      post_data["post.activity_icon_class"] = activity_icon_class

      posts_list += load_html("year_stats/post_row", post_data)
    end
    posts_list += "</ul>\n"
    data["posts_list"] = posts_list

    return load_html("year_stats/stats", data)
  end

  private def hours
    return @posts.select { |p| p.self_propelled? }.map { |p| p.time_spent.as(Float64) }.sum
  end

  private def distance
    return @posts.select { |p| p.self_propelled? }.map { |p| p.distance.as(Float64) }.sum
  end

  private def voivodeships_stats
    voivoids = @blog.data_manager.not_nil!.voivodeships.not_nil!
    d = Hash(String, Int32).new
    @posts.each do |post|
      vs = post.towns.not_nil!.select { |t| voivoids.map(&.slug).includes?(t) }
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

  private def bibycle_distance
    return @posts.select { |p| p.bicycle? }.map { |p| p.distance.as(Float64) }.sum
  end

  private def bicycle_hours
    return @posts.select { |p| p.bicycle? }.map { |p| p.time_spent.as(Float64) }.sum
  end

  private def generate_image_url
    return @posts.select { |p| true }.sort { |a, b|
      b.distance.not_nil! <=> a.distance.not_nil!
    }.first.image_url
  end
end
