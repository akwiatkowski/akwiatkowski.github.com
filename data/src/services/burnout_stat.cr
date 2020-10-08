class BurnoutStat
  Log = ::Log.for(self)

  alias BurnoutTuple = NamedTuple(
    month: Time,
    distance: Int32,
    distance_last_year: Int32?,
    distance_change: Int32?,
    distance_change_percent: Int32?,

    time_spent: Int32,
    time_spent_last_year: Int32?,
    time_spent_change: Int32?,
    time_spent_change_percent: Int32?,
  )
  alias MonthStatTuple = NamedTuple(
    distance: Int32,
    time_spent: Int32
  )

  def initialize(@blog : Tremolite::Blog)
    @posts = @blog.post_collection.posts.sort do |a,b|
      a.time <=> b.time
    end.as(Array(Tremolite::Post))

    @month_from = @posts.first.time.at_beginning_of_month.as(Time)
    @month_to = Time.local.at_end_of_month.as(Time)
  end

  def make_it_so
    data = Array(BurnoutTuple).new
    month_data = Hash(Time, MonthStatTuple).new

    # preprocessing post data
    month = @month_from
    while month <= @month_to
      posts_in_month = @posts.select do |post|
        post.time >= month.at_beginning_of_month && post.time < month.at_end_of_month
      end

      time_spent = 0
      distance = 0

      posts_in_month.each do |post|
        if post.trip? && ! post.time_spent.nil?
          time_spent += post.time_spent.not_nil!.to_i
        end

        if post.self_propelled? && ! post.time_spent.nil?
          distance += post.distance.not_nil!.to_i
        end
      end

      month_data[month] = MonthStatTuple.new(
        time_spent: time_spent,
        distance: distance
      )

      # TODO add to Time struct
      month = (month.at_end_of_month + Time::MonthSpan.new(1)).at_beginning_of_month
    end

    # burnout calculation
    month = @month_from
    while month <= @month_to
      month_year_before_time = (month.at_end_of_month - Time::MonthSpan.new(12)).at_beginning_of_month
      month_year_before = month_data[month_year_before_time]?

      distance_last_year= nil
      distance_change = nil
      distance_change_percent = nil

      time_spent_last_year= nil

      if month_year_before
        distance_year_before = month_year_before[:distance]
        distance_current_month = month_data[month][:distance]
        if distance_year_before > 0 && distance_current_month > 0
          distance_last_year = distance_year_before
          distance_change = distance_current_month - distance_year_before
          distance_change_percent = ((distance_change.to_f / distance_year_before.to_f) * 100.0).to_i
        end

        time_spent_year_before = month_year_before[:time_spent]
        time_spent_current_month = month_data[month][:time_spent]
        if time_spent_year_before > 0 && time_spent_current_month > 0
          time_spent_last_year = time_spent_year_before
          time_spent_change = time_spent_current_month - time_spent_year_before
          time_spent_change_percent = ((time_spent_change.to_f / time_spent_year_before.to_f) * 100.0).to_i
        end
      end

      data << BurnoutTuple.new(
        month: month,

        distance: month_data[month][:distance],
        distance_last_year: distance_last_year,
        distance_change: distance_change,
        distance_change_percent: distance_change_percent,

        time_spent: month_data[month][:time_spent],
        time_spent_last_year: time_spent_last_year,
        time_spent_change: time_spent_change,
        time_spent_change_percent: time_spent_change_percent,
      )

      # TODO add to Time struct
      month = (month.at_end_of_month + Time::MonthSpan.new(1)).at_beginning_of_month
    end

    return data
  end
end
