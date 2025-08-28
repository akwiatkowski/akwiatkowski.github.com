require "./exif_stat_type"

struct ExifStatStruct
  Log = ::Log.for(self)

  getter :is_zoom
  getter :count_by_focal35
  getter :count_by_month_and_focal35

  TIME_FROM_KEY = :time_from
  TIME_TO_KEY   = :time_to

  def initialize(
    @type : ExifStatType,
    @key_name : String = "",
  )
    @count_by_day = Hash(Time, Int32).new
    @count_by_month = Hash(Time, Int32).new
    @count_by_year = Hash(Int32, Int32).new

    @times = Hash(Symbol, Time).new

    @count_by_focal35 = Hash(Int32, Int32).new
    @count_by_month_and_focal35 = Hash(Time, Hash(Int32, Int32)).new

    @is_zoom = false
    # if it's lens type check it lens (key_name) is zoom
    if @type == ExifStatType::Lens
      @is_zoom = self.class.is_zoom?(@key_name).as(Bool)
    end
  end

  def increment(
    photo : PhotoEntity,
    post : Tremolite::Post | Nil = nil,
  ) : Bool
    focal = photo.exif.focal_length_35
    return false if focal.nil?

    focal_int = focal.not_nil!.round.to_i
    time = photo.exif.time.not_nil!
    day = time.at_beginning_of_day
    month = time.at_beginning_of_month
    year = time.year

    # hash counts
    @count_by_focal35[focal_int] ||= 0
    @count_by_focal35[focal_int] += 1

    @count_by_day[day] ||= 0
    @count_by_day[day] += 1

    @count_by_month[month] ||= 0
    @count_by_month[month] += 1

    @count_by_month_and_focal35[month] ||= Hash(Int32, Int32).new
    @count_by_month_and_focal35[month][focal_int] ||= 0
    @count_by_month_and_focal35[month][focal_int] += 1

    @count_by_year[year] ||= 0
    @count_by_year[year] += 1

    # update extreme time ranges
    @times[TIME_FROM_KEY] ||= time
    @times[TIME_FROM_KEY] = time if @times[TIME_FROM_KEY] > time

    @times[TIME_TO_KEY] ||= time
    @times[TIME_TO_KEY] = time if @times[TIME_TO_KEY] < time

    return true
  end

  def count
    @count_by_year.values.sum
  end

  # calculate number of photos taken between focal lenghts
  def count_between_focal35(
    ranges : Array,
    except : Array = Array(NamedTuple(from: Int32, to: Int32)).new,
  )
    return @count_by_focal35.to_a.select do |focal, count|
      negative_results = except.map do |range|
        focal >= range[:from].as(Int32) && focal <= range[:to].as(Int32)
      end

      # if negative_results is empty -> range was not removed
      if negative_results.select { |r| r }.size > 0
        false
      else
        # Array(Bool)
        results = ranges.map do |range|
          focal >= range[:from].as(Int32) && focal <= range[:to].as(Int32)
        end
        # at least one element should be true
        results.select { |r| r }.size > 0
      end
    end.map do |focal, count|
      count
    end.sum
  end

  def time_from
    @times[TIME_FROM_KEY]?
  end

  def time_to
    @times[TIME_TO_KEY]?
  end

  def day_distance
    return nil if time_to.nil? || time_from.nil?
    return (time_to.not_nil! - time_from.not_nil!).days
  end

  def day_distance_to_now
    return nil if time_from.nil?
    return (Time.local - time_from.not_nil!).days
  end

  def last_used_days_ago
    return nil if time_to.nil?
    return (Time.local - time_to.not_nil!).days
  end

  def average_per_month
    return nil if day_distance.nil?
    return (count.to_f * 30.0 / day_distance.not_nil!.to_f).round.to_i
  end

  def average_per_month_to_now
    return nil if day_distance_to_now.nil?
    return (count.to_f * 30.0 / day_distance_to_now.not_nil!.to_f).round.to_i
  end

  # meaningful:
  # * ignore short
  # * when still used calculate till now
  def smart_avg_per_month
    if day_distance.nil? || day_distance.not_nil! < 30
      return nil
    elsif last_used_days_ago.nil?
      return nil
    elsif last_used_days_ago.not_nil! < 100
      return average_per_month_to_now
    else
      return average_per_month
    end
  end

  def self.is_zoom?(lens_name) : Bool
    # instead of hardcoded names it's better to check regexp
    if lens_name =~ /(\d)+\-(\d+)/
      return true
    else
      return false
    end
  end
end
