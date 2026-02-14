module DynamicView
  class YearStatReportView < PageView
    Log = ::Log.for(self)

    POLISH_MONTHS = {
      1 => "Styczeń", 2 => "Luty", 3 => "Marzec",
      4 => "Kwiecień", 5 => "Maj", 6 => "Czerwiec",
      7 => "Lipiec", 8 => "Sierpień", 9 => "Wrzesień",
      10 => "Październik", 11 => "Listopad", 12 => "Grudzień",
    }

    SYSTEM_TAGS = Set{"photo_of_the_year", "todo", "todo_media", "hidden"}

    YS_MAP_JS = <<-JS
    (function() {
      var el = document.getElementById('ys-map');
      var dataEl = document.getElementById('ys-route-data');
      if (!el || !dataEl) return;
      var data = JSON.parse(dataEl.textContent);
      var map = L.map('ys-map', {
        scrollWheelZoom: false,
        attributionControl: false,
        zoomControl: true
      });
      L.tileLayer('/tiles/ump/{z}/{x}/{y}.png', {
        maxZoom: 16, minZoom: 6
      }).addTo(map);
      var bbox = data.bbox;
      map.fitBounds([[bbox.south, bbox.west], [bbox.north, bbox.east]], { padding: [20, 20] });
      data.routes.forEach(function(r) {
        var style = window.getRouteStyle(r.tags);
        var line = L.polyline(r.coords, style);
        if (r.title) line.bindTooltip(r.title);
        line.addTo(map);
      });
    })();
    JS

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

    def additional_bundles : Array(String)
      has_routes? ? ["leaflet"] : [] of String
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

      # Two-pass month accumulation (shared by sparkline + bar charts + table)
      month_rows = accumulate_month_data
      max_month_distance = month_rows.max_of? { |r| r[:distance] } || 0

      # Sparkline
      distances = month_rows.map { |r| r[:distance] }
      data["sparkline_html"] = sparkline_svg(distances)

      # Months list with bar charts
      months_list = ""
      month_rows.each do |row|
        month_data = Hash(String, String).new
        month_data["month"] = row[:name]
        month_data["month.distance"] = row[:distance].to_s
        month_data["month.distance_bicycle"] = row[:distance_bicycle].to_s
        month_data["month.distance_hike"] = row[:distance_hike].to_s
        month_data["month.time_spent"] = row[:time_spent].to_s
        month_data["season_class"] = row[:season_class]
        month_data["month.bar_svg"] = month_bar_svg(row[:distance], max_month_distance)
        months_list += load_html("year_stats/month_row", month_data)
      end
      data["months_list"] = months_list

      # New sections
      data["poty_html"] = photo_of_the_year_html
      data["tags_html"] = tag_breakdown_html
      data["records_html"] = records_html
      data["map_html"] = map_of_the_year_html

      return load_html("year_stats/stats", data)
    end

    # ============================================
    # Month Data Accumulation (Two-Pass)
    # ============================================

    private alias MonthRow = NamedTuple(
      name: String,
      distance: Int32,
      distance_bicycle: Int32,
      distance_hike: Int32,
      time_spent: Int32,
      season_class: String,
    )

    private def accumulate_month_data : Array(MonthRow)
      rows = Array(MonthRow).new
      (1..12).each do |month|
        time = Time.local(@year, month, 1).at_beginning_of_month
        next unless time < Time.local

        month_distance = 0
        month_distance_bicycle = 0
        month_distance_hike = 0
        month_time_spent = 0

        @posts.select { |post| post.time.month == month }.each do |post|
          post_distance = post.distance.as(Float64).ceil.to_i
          post_time_spent = post.time_spent.as(Float64).ceil.to_i

          if post.self_propelled?
            month_distance += post_distance
            month_time_spent += post_time_spent
          end
          if post.bicycle?
            month_distance_bicycle += post_distance
          end
          if post.hike? || post.walk?
            month_distance_hike += post_distance
          end
        end

        rows << {
          name:             POLISH_MONTHS[month],
          distance:         month_distance,
          distance_bicycle: month_distance_bicycle,
          distance_hike:    month_distance_hike,
          time_spent:       month_time_spent,
          season_class:     season_class(month),
        }
      end
      rows
    end

    # ============================================
    # Feature 1: Mini Bar Charts
    # ============================================

    private def month_bar_svg(value : Int32, max_value : Int32) : String
      return "" if max_value == 0
      width = (value.to_f / max_value * 70).round.to_i
      "<svg width=\"80\" height=\"16\" class=\"ys-bar-svg\"><rect x=\"0\" y=\"2\" width=\"#{width}\" height=\"12\" rx=\"2\" fill=\"var(--ys-accent)\" opacity=\"0.7\"/></svg>"
    end

    # ============================================
    # Feature 2: Photo of the Year
    # ============================================

    private def photo_of_the_year_html : String
      poty = @posts.select(&.photo_of_the_year?)
      return "" if poty.empty?
      post = poty.first
      String.build do |s|
        s << "<div class=\"ys-poty\">"
        s << "<a href=\"#{post.url}\">"
        s << "<img src=\"#{post.card_image_url}\" alt=\"Zdjęcie roku #{@year}\" loading=\"lazy\">"
        s << "<div class=\"ys-poty-overlay\">"
        s << "<span class=\"ys-poty-badge\">Zdjęcie roku #{@year}</span>"
        s << "<span class=\"ys-poty-title\">#{post.title}</span>"
        s << "</div>"
        s << "</a>"
        s << "</div>"
      end
    end

    # ============================================
    # Feature 3: Monthly Sparkline
    # ============================================

    private def sparkline_svg(distances : Array(Int32)) : String
      return "" if distances.empty?

      w = 300
      h = 40
      pad_x = 10
      pad_y = 4
      max_val = distances.max
      return "" if max_val == 0

      plot_w = w - 2 * pad_x
      plot_h = h - 2 * pad_y
      n = distances.size

      points = distances.map_with_index do |d, i|
        x = if n > 1
              pad_x + (i.to_f / (n - 1) * plot_w)
            else
              w / 2.0
            end
        y = pad_y + plot_h - (d.to_f / max_val * plot_h)
        {x.round(1), y.round(1)}
      end

      points_str = points.map { |x, y| "#{x},#{y}" }.join(" ")

      String.build do |s|
        s << "<svg width=\"#{w}\" height=\"#{h}\" class=\"ys-sparkline-svg\" viewBox=\"0 0 #{w} #{h}\">"
        # Filled area
        if n > 1
          fill_pts = points_str + " #{points.last[0]},#{h - pad_y} #{points.first[0]},#{h - pad_y}"
          s << "<polygon points=\"#{fill_pts}\" fill=\"var(--ys-accent)\" opacity=\"0.15\"/>"
          s << "<polyline points=\"#{points_str}\" fill=\"none\" stroke=\"var(--ys-accent)\" stroke-width=\"2\" stroke-linejoin=\"round\"/>"
        end
        # Dots
        points.each do |x, y|
          s << "<circle cx=\"#{x}\" cy=\"#{y}\" r=\"3\" fill=\"var(--ys-accent)\"/>"
        end
        s << "</svg>"
      end
    end

    # ============================================
    # Feature 4: Map of the Year
    # ============================================

    private def has_routes? : Bool
      @posts.any? { |p| p.has_detailed_route? || p.detailed_routes.size > 0 }
    end

    private def map_of_the_year_html : String
      posts_with_routes = @posts.select { |p| p.has_detailed_route? || p.detailed_routes.size > 0 }
      return "" if posts_with_routes.empty?

      # Build route JSON
      route_json = JSON.build do |json|
        json.object do
          # Precompute bounding box
          all_lats = [] of Float64
          all_lons = [] of Float64
          routes_data = [] of {post: Tremolite::Post, route: PostRouteObject}

          posts_with_routes.each do |post|
            post.detailed_routes.each do |route|
              routes_data << {post: post, route: route}
              route.route.each do |point|
                if point.size >= 2
                  all_lats << point[0]
                  all_lons << point[1]
                end
              end
            end
          end

          if all_lats.empty?
            json.field "bbox" do
              json.object do
                json.field("south", 51.0)
                json.field("north", 52.0)
                json.field("west", 17.0)
                json.field("east", 18.0)
              end
            end
          else
            json.field "bbox" do
              json.object do
                json.field("south", all_lats.min)
                json.field("north", all_lats.max)
                json.field("west", all_lons.min)
                json.field("east", all_lons.max)
              end
            end
          end

          json.field "routes" do
            json.array do
              posts_with_routes.each do |post|
                post.detailed_routes.each do |route|
                  json.object do
                    json.field("title", "#{post.title} (#{post.date})")
                    json.field("tags") { json.raw post.tag_slugs.to_json }
                    json.field "coords" do
                      json.array do
                        route.route.each do |point|
                          json.array do
                            point.each { |v| json.number(v) }
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      String.build do |s|
        s << "<h3 class=\"ys-section-title\">Mapa tras</h3>"
        s << "<div class=\"ys-map-container\">"
        s << "<div id=\"ys-map\"></div>"
        s << "</div>"
        s << "<script id=\"ys-route-data\" type=\"application/json\">#{route_json}</script>"
        s << "<script>#{YS_MAP_JS}</script>"
      end
    end

    # ============================================
    # Feature 5: Tag Breakdown
    # ============================================

    private def tag_breakdown_html : String
      tag_counts = Hash(String, Int32).new(0)
      @posts.each do |post|
        post.tag_slugs.each do |slug|
          next if SYSTEM_TAGS.includes?(slug)
          tag_counts[slug] += 1
        end
      end

      # Filter to tags with ≥2 occurrences, sort by count desc
      visible = tag_counts.to_a.select { |_, count| count >= 2 }.sort_by { |_, count| -count }
      return "" if visible.empty?

      String.build do |s|
        s << "<h3 class=\"ys-section-title\">Tagi</h3>"
        s << "<div class=\"ys-tags\">"
        visible.each do |slug, count|
          tag = context.tags.find { |t| t.slug == slug }
          if tag
            s << "<a href=\"#{tag.view_url}\" class=\"ys-tag-chip\">"
            s << tag.name
            s << "<span class=\"ys-tag-count\">#{count}</span>"
            s << "</a>"
          end
        end
        s << "</div>"
      end
    end

    # ============================================
    # Feature 6: Records
    # ============================================

    private def records_html : String
      records = [] of NamedTuple(label: String, this_year: String, all_time: String, is_record: Bool)

      # Record 1: Longest single trip
      year_longest = @posts.select(&.self_propelled?).max_by? { |p| p.distance.as(Float64) }
      all_longest = context.posts.select(&.self_propelled?).max_by? { |p| p.distance.as(Float64) }
      if year_longest
        year_val = year_longest.distance.as(Float64).ceil.to_i
        all_val = all_longest ? all_longest.distance.as(Float64).ceil.to_i : 0
        records << {
          label:     "Najdłuższa trasa",
          this_year: "#{year_val} km",
          all_time:  "#{all_val} km",
          is_record: year_val >= all_val && all_val > 0,
        }
      end

      # Record 2: Most active month (distance)
      month_rows = accumulate_month_data
      year_max_month = month_rows.max_by? { |r| r[:distance] }

      # All-time max month
      all_time_max_month_dist = 0
      context.years.each do |y|
        y_posts = context.posts.select { |p| p.time.year == y }
        (1..12).each do |m|
          m_dist = y_posts.select { |p| p.time.month == m && p.self_propelled? }
            .sum(0) { |p| p.distance.as(Float64).ceil.to_i }
          all_time_max_month_dist = m_dist if m_dist > all_time_max_month_dist
        end
      end

      if year_max_month && year_max_month[:distance] > 0
        records << {
          label:     "Najaktywniejszy miesiąc",
          this_year: "#{year_max_month[:distance]} km",
          all_time:  "#{all_time_max_month_dist} km",
          is_record: year_max_month[:distance] >= all_time_max_month_dist && all_time_max_month_dist > 0,
        }
      end

      # Record 3: Most posts in a year
      year_post_count = @posts.size
      all_time_max_posts = context.years.map { |y| context.posts.count { |p| p.time.year == y } }.max? || 0
      if year_post_count > 0
        records << {
          label:     "Wpisów w roku",
          this_year: year_post_count.to_s,
          all_time:  all_time_max_posts.to_s,
          is_record: year_post_count >= all_time_max_posts && all_time_max_posts > 0,
        }
      end

      return "" if records.empty?

      String.build do |s|
        s << "<h3 class=\"ys-section-title\">Rekordy</h3>"
        s << "<div class=\"ys-records\">"
        records.each do |r|
          card_class = r[:is_record] ? "ys-record-card ys-record-best" : "ys-record-card"
          s << "<div class=\"#{card_class}\">"
          s << "<div class=\"ys-record-label\">#{r[:label]}</div>"
          s << "<div class=\"ys-record-value\">#{r[:this_year]}</div>"
          s << "<div class=\"ys-record-compare\">Rekord: #{r[:all_time]}"
          if r[:is_record]
            s << " <span class=\"ys-record-badge\">Rekord!</span>"
          end
          s << "</div>"
          s << "</div>"
        end
        s << "</div>"
      end
    end

    # ============================================
    # Existing Helpers
    # ============================================

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
