class YearStatReportView < PageView
  Log = ::Log.for(self)

  BICYCLE_MAX_DISTANCE = 800.0
  HIKE_MAX_DISTANCE    = 100.0
  OPACITY_MAX          =   1.0
  OPACITY_MIN          =  0.02

  def initialize(@blog : Tremolite::Blog,
                 @year : Int32,
                 @all_years : Array(Int32))
    @posts = @blog.post_collection.posts.select { |p| p.time.year == @year }.as(Array(Tremolite::Post))
    @image_url = generate_image_url.as(String)
    @title = "#{@year}"
    @subtitle = "Podsumowanie roku #{@year}, czyli #{hours.to_i} godzin i #{distance.to_i} kilometrów w terenie"
    @url = "/year/#{@year}"

    @data_manager = @blog.data_manager.as(Tremolite::DataManager)
  end

  getter :image_url, :title, :subtitle, :year
  property :url

  def inner_html
    data = Hash(String, String).new
    data["year"] = @year.to_s
    data["post.count"] = @posts.size.to_i.to_s

    data["hours"] = hours.to_i.to_s
    data["distance"] = distance.to_i.to_s

    data["bicycle_distance"] = bicycle_distance.to_i.to_s
    data["bicycle_hours"] = bicycle_hours.to_i.to_s

    voivodeships_stats_strings = Array(String).new
    voivodeships_stats.keys.each do |k|
      voivodeships_stats_strings << "#{k} - #{voivodeships_stats[k]} razy"
    end
    data["voivodeships_stats"] = "<ol>\n"
    voivodeships_stats_strings.each do |s|
      data["voivodeships_stats"] += "<li>#{s}</li>\n"
    end
    data["voivodeships_stats"] += "</ol>\n"

    years_strings = Array(String).new
    @all_years.each do |y|
      if @year != y
        years_strings << "<a href=\"/year/#{y}\">#{y}</a>"
      else
        years_strings << "<strong>#{y}</strong>"
      end
    end
    data["other_year_links"] = years_strings.join(", ")

    # post lists
    posts_list = ""
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
      elsif post.bus?
        activity_icon_class = "icon-bus"
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
    data["posts_list"] = posts_list

    # months list
    months_list = ""
    (1..12).each do |month|
      time = Time.local(@year, month, 1).at_beginning_of_month
      if time < Time.local
        month_data = Hash(String, String).new

        month_distance = 0
        month_distance_bicycle = 0
        month_distance_hike = 0
        month_time_spent = 0

        @posts.select { |post| post.time.month == month }.each do |post|
          post_distance = post.distance.as(Float64).ceil.to_i
          post_time_spent = post.time_spent.as(Float64).ceil.to_i

          if post.self_propelled?
            month_distance += post_distance.to_i
            month_time_spent += post_time_spent.to_i
          end
          if post.bicycle?
            month_distance_bicycle += post_distance.to_i
          end
          if post.hike? || post.walk?
            month_distance_hike += post_distance.to_i
          end
        end

        month_data["month"] = month.to_s
        month_data["month.distance"] = month_distance.to_s
        month_data["month.distance_bicycle"] = month_distance_bicycle.to_s
        month_data["month.distance_hike"] = month_distance_hike.to_s
        month_data["month.time_spent"] = month_time_spent.to_s

        bicycle_opacity = month_distance_bicycle.to_f / BICYCLE_MAX_DISTANCE
        bicycle_opacity = OPACITY_MAX if bicycle_opacity > OPACITY_MAX
        bicycle_opacity = OPACITY_MIN if bicycle_opacity < OPACITY_MIN
        month_data["month.style_distance_bicycle"] = "background-color: rgba(100,100,255,#{bicycle_opacity});"

        hike_opacity = month_distance_hike.to_f / HIKE_MAX_DISTANCE
        hike_opacity = OPACITY_MAX if bicycle_opacity > OPACITY_MAX
        hike_opacity = OPACITY_MIN if bicycle_opacity < OPACITY_MIN
        month_data["month.style_distance_hike"] = "background-color: rgba(100,255,100,#{hike_opacity});"

        months_list += load_html("year_stats/month_row", month_data)
      end
    end
    data["months_list"] = months_list

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
    voivoids_hash_keys = Hash(String, Int32).new
    @posts.each do |post|
      vs = post.towns.not_nil!.select { |t| voivoids.map(&.slug).includes?(t) }
      vs.each do |v|
        if voivoids_hash_keys[v]?
          voivoids_hash_keys[v] += 1
        else
          voivoids_hash_keys[v] = 1
        end
      end
    end

    # convert slugs to names
    voivoids_hash_names = Hash(String, Int32).new
    voivoids_hash_keys.keys.each do |key|
      voivodeship_name = @data_manager.voivodeships.not_nil!.select { |v| v.slug == key }.first.name
      voivoids_hash_names[voivodeship_name] = voivoids_hash_keys[key]
    end

    return voivoids_hash_names
  end

  private def bicycle_distance
    return @posts.select { |p| p.bicycle? }.map { |p| p.distance.as(Float64) }.sum
  end

  private def bicycle_hours
    return @posts.select { |p| p.bicycle? }.map { |p| p.time_spent.as(Float64) }.sum
  end

  private def generate_image_url
    # selected posts with proper tag
    posts_photo_of_the_year = @posts.select { |p| p.photo_of_the_year? }
    # or longest self propelled trip
    if posts_photo_of_the_year.size == 0
      posts_photo_of_the_year = @posts.select { |p| p.self_propelled? }.sort { |a, b|
        b.distance.not_nil! <=> a.distance.not_nil!
      }
    end
    if posts_photo_of_the_year.size > 0
      return posts_photo_of_the_year.first.image_url
    else
      return ""
    end
  end
end
