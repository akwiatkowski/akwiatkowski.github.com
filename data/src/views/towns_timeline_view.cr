class TownsTimelineView < PageView
  def initialize(@blog : Tremolite::Blog, @url : String)
    @image_url = @blog.data_manager.not_nil!["towns_timeline.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["towns_timeline.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["towns_timeline.subtitle"].as(String)

    @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))

    @times = [@posts.first.time, @posts.last.time].as(Array(Time))
    @time_from = @times.min.as(Time)
    @time_to = @times.max.as(Time)

    @towns = @blog.data_manager.not_nil!.towns.as(Array(TownEntity))
    @town_slugs = @towns.map { |town| town.slug }.as(Array(String))

    @self_propelled = Hash(Time, Array(TownEntity)).new
    @vehicle_propelled = Hash(Time, Array(TownEntity)).new

    @self_propelled_array = Array(TownEntity).new
    @vehicle_propelled_array = Array(TownEntity).new

    @self_repeated_sum = 0
    @self_repeated = Hash(Time, Int32).new
    @self_monthly = Hash(Time, Int32).new

    prepare_data
  end

  getter :image_url, :title, :subtitle

  def inner_html
    s = ""

    s += inner_content

    return s
  end

  private def inner_content
    s = ""
    previous_self_propelled = 0

    time = @time_from.at_beginning_of_month
    while time < @time_to.at_end_of_month
      s += month_content(
        time: time,
        previous_self_propelled: previous_self_propelled
      )
      # for total count
      previous_self_propelled += @self_propelled[time].size if @self_propelled[time]?

      # next month
      time = time.at_end_of_month
      time += Time::Span.new(1, 0, 0)
      time = time.at_beginning_of_month
    end

    return s
  end

  private def month_content(time : Time, previous_self_propelled : Int32) : String
    if (@self_propelled[time]?.nil? || @self_propelled[time].size == 0) &&
       (@vehicle_propelled[time]?.nil? || @vehicle_propelled[time].size == 0)
      return ""
    end

    data = Hash(String, String).new
    data["month"] = time.to_s("%m")
    data["year"] = time.to_s("%Y")
    data["list"] = month_towns_list(
      self_propelled_for_month: @self_propelled[time],
      vehicle_propelled_for_month: @vehicle_propelled[time],
    )
    data["total-self"] = (previous_self_propelled + @self_propelled[time].size).to_s
    data["repeated-self"] = (@self_repeated[time]? || 0).to_s
    data["monthly-self"] = (@self_monthly[time]? || 0).to_s

    if @self_propelled[time].size > 0
      data["count_self_propelled"] = @self_propelled[time].size.to_s
    else
      data["count_self_propelled"] = "0"
    end

    if @vehicle_propelled[time].size > 0
      data["count_vehicle_propelled"] = @vehicle_propelled[time].size.to_s
    else
      data["count_vehicle_propelled"] = "0"
    end

    return load_html("towns_timeline/month", data)
  end

  def month_towns_list(
    self_propelled_for_month : Array(TownEntity),
    vehicle_propelled_for_month : Array(TownEntity)
  )
    s = ""
    self_propelled_for_month.each_with_index do |town_entity, i|
      data = Hash(String, String).new
      data["town.slug"] = town_entity.slug
      data["town.name"] = town_entity.name
      data["class"] = "timeline-self-propelled"
      data["count"] = (i + 1).to_s
      s += load_html("towns_timeline/town", data)
    end

    vehicle_propelled_for_month.each_with_index do |town_entity, i|
      data = Hash(String, String).new
      data["town.slug"] = town_entity.slug
      data["town.name"] = town_entity.name
      data["class"] = "timeline-vehicle-propelled"
      data["count"] = (i + 1).to_s
      s += load_html("towns_timeline/town", data)
    end

    return s
  end

  private def prepare_data
    t = @time_from.at_beginning_of_month
    while t < @time_to.at_end_of_month
      get_towns_in_month(time: t)

      # next month
      t = t.at_end_of_month
      t += Time::Span.new(1, 0, 0)
      t = t.at_beginning_of_month
    end
  end

  private def get_towns_in_month(time : Time)
    formatted_time = time.at_beginning_of_month
    # set default values in Hash
    unless @self_propelled[formatted_time]?
      @self_propelled[formatted_time] = Array(TownEntity).new
    end
    unless @vehicle_propelled[formatted_time]?
      @vehicle_propelled[formatted_time] = Array(TownEntity).new
    end
    unless @self_repeated[formatted_time]?
      # this is sum
      @self_repeated[formatted_time] = @self_repeated_sum
    end
    unless @self_monthly[formatted_time]?
      @self_monthly[formatted_time] = 0
    end

    posts_in_month = @posts.select { |p|
      p.time >= time.at_beginning_of_month &&
        p.time < time.at_end_of_month
    }
    posts_in_month.each do |post|
      process_towns_in_month_post(time: formatted_time, post: post)
    end

    # store sum
    @self_repeated_sum = @self_repeated[formatted_time]
  end

  private def process_towns_in_month_post(time : Time, post : Tremolite::Post)
    formatted_time = time

    towns_in_post = post.towns.not_nil!.select { |town|
      @town_slugs.includes?(town)
    }

    towns_in_post.each do |town_slug|
      # iterate all towns (not voivodeships) in post
      town_entity = @towns.select { |town| town.slug == town_slug }.first.as(TownEntity)
      # and add if not already added

      if post.self_propelled?
        # check if it wasn't already added
        unless @self_propelled_array.includes?(town_entity)
          unless @self_propelled[formatted_time].includes?(town_entity)
            @self_propelled[formatted_time] << town_entity
          end
          @self_propelled_array << town_entity
        else
          # increment repeated sum counter
          @self_repeated[formatted_time] += 1
        end
        # increment monthly sum counter
        @self_monthly[formatted_time] += 1
      else
        # don't add vehicle_propelled if was already added
        # by self_propelled
        unless @vehicle_propelled_array.includes?(town_entity) ||
               @self_propelled_array.includes?(town_entity)
          unless @vehicle_propelled[formatted_time].includes?(town_entity)
            @vehicle_propelled[formatted_time] << town_entity
          end
          @vehicle_propelled_array << town_entity
        end
      end
    end
  end
end
