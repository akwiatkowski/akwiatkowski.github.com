module DynamicView
  class YearStatReportView < PageView
    Log = ::Log.for(self)

    POLISH_MONTHS = {
      1 => "Styczeń", 2 => "Luty", 3 => "Marzec",
      4 => "Kwiecień", 5 => "Maj", 6 => "Czerwiec",
      7 => "Lipiec", 8 => "Sierpień", 9 => "Wrzesień",
      10 => "Październik", 11 => "Listopad", 12 => "Grudzień",
    }

    def initialize(
      context : RenderContext,
      @year : Int32,
      @all_years : Array(Int32),
    )
      @posts = context.posts.select { |p| p.time.year == @year }.as(Array(Tremolite::Post))
      @image_url = generate_image_url.as(String)
      @title = "#{@year}"
      @subtitle = "Podsumowanie roku #{@year}, czyli #{hours.to_i} godzin i #{distance.to_i} kilometrów w terenie"
      @url = self.class.url_for_year(@year)

      super(context: context, url: @url)
    end

    getter :image_url, :title, :subtitle, :year

    property :url

    def add_to_sitemap?
      true
    end

    def page_css : Array(String)
      ["year_stats"]
    end

    def self.url_for_year(year)
      return "/rok/#{year}.html"
    end

    def inner_html
      data = Hash(String, String).new
      data["year"] = @year.to_s
      data["post.count"] = @posts.size.to_s

      data["hours"] = hours.to_i.to_s
      data["distance"] = distance.to_i.to_s

      data["bicycle_distance"] = bicycle_distance.to_i.to_s
      data["bicycle_hours"] = bicycle_hours.to_i.to_s

      # Activity breakdown
      bicycle_count = @posts.count(&.bicycle?)
      hike_count = @posts.count(&.hike?)
      data["bicycle_count"] = bicycle_count.to_s
      data["hike_count"] = hike_count.to_s

      # Voivodeships visited
      voivs = @posts.flat_map(&.voivodeship_entities).uniq(&.slug).sort_by(&.name)
      data["voivodeships_stats"] = voivs.map { |v| "<a href=\"#{v.view_url}\">#{v.name}</a>" }.join(", ")

      # Longest trip
      longest = @posts.select(&.self_propelled?).max_by? { |p| p.distance.as(Float64) }
      if longest
        data["longest_html"] = "<p>Najdłuższa trasa: <a href=\"#{longest.url}\">#{longest.title}</a> — #{longest.distance.as(Float64).ceil.to_i} km</p>"
      else
        data["longest_html"] = ""
      end

      # Averages
      sp = @posts.select(&.self_propelled?)
      if sp.size > 0
        avg_dist = (distance / sp.size).round(1)
        avg_hrs = (hours / sp.size).round(1)
        data["avg_stats"] = "Średnio #{avg_dist} km i #{avg_hrs} h na wyprawę."
      else
        data["avg_stats"] = ""
      end

      # New towns discovered this year
      prior_town_slugs = Set(String).new
      context.posts.each do |p|
        prior_town_slugs.concat(p.town_slugs) if p.time.year < @year
      end
      this_year_towns = Set(String).new
      @posts.each { |p| this_year_towns.concat(p.town_slugs) }
      new_towns = this_year_towns - prior_town_slugs
      data["new_towns_count"] = new_towns.size.to_s
      data["total_towns_count"] = this_year_towns.size.to_s

      # Year-over-year delta
      if @year > @all_years.min
        prev_posts = context.posts.select { |p| p.time.year == @year - 1 }
        prev_distance = prev_posts.select(&.self_propelled?).sum(0.0) { |p| p.distance.as(Float64) }
        prev_hours = prev_posts.select(&.self_propelled?).sum(0.0) { |p| p.time_spent.as(Float64) }
        delta_km = (distance - prev_distance).round.to_i
        delta_hours = (hours - prev_hours).round.to_i
        delta_km_str = delta_km >= 0 ? "+#{delta_km}" : delta_km.to_s
        delta_hours_str = delta_hours >= 0 ? "+#{delta_hours}" : delta_hours.to_s
        data["delta_html"] = "<p>Względem #{@year - 1}: <span class=\"ys-delta\">#{delta_km_str} km</span> <span class=\"ys-delta\">#{delta_hours_str} h</span></p>"
      else
        data["delta_html"] = ""
      end

      # Year navigation links
      years_strings = Array(String).new
      @all_years.each do |y|
        if @year != y
          years_strings << "<a href=\"#{self.class.url_for_year(y)}\">#{y}</a>"
        else
          years_strings << "<strong>#{y}</strong>"
        end
      end
      data["other_year_links"] = years_strings.join("\n  ")

      # Post list
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

      # Months list
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

          month_data["month"] = POLISH_MONTHS[month]
          month_data["month.distance"] = month_distance.to_s
          month_data["month.distance_bicycle"] = month_distance_bicycle.to_s
          month_data["month.distance_hike"] = month_distance_hike.to_s
          month_data["month.time_spent"] = month_time_spent.to_s
          month_data["season_class"] = season_class(month)

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

    private def bicycle_distance
      return @posts.select { |p| p.bicycle? }.map { |p| p.distance.as(Float64) }.sum
    end

    private def bicycle_hours
      return @posts.select { |p| p.bicycle? }.map { |p| p.time_spent.as(Float64) }.sum
    end

    private def season_class(month : Int32) : String
      case month
      when 12, 1, 2 then "month-winter"
      when 3, 4, 5  then "month-spring"
      when 6, 7, 8  then "month-summer"
      else               "month-fall"
      end
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
end
