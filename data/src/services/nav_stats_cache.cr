struct NavStatsCacheObject
  include YAML::Serializable

  @bicycle_distance : Int32 = 0
  @bicycle_time_length : Int32 = 0
  @bicycle_count : Int32 = 0
  @hike_distance : Int32 = 0
  @hike_time_length : Int32 = 0
  @hike_count : Int32 = 0
  @train_distance : Int32 = 0
  @train_time_length : Int32 = 0
  @train_count : Int32 = 0
  @self_distance : Int32 = 0
  @self_time_length : Int32 = 0
  @updated_at : Time = Time.local

  property :bicycle_distance, :bicycle_time_length, :bicycle_count,
    :hike_distance, :hike_time_length,  :hike_count,
    :train_distance, :train_time_length, :train_count,
    :self_distance, :self_time_length,
    :updated_at

  def initialize
  end
end

class NavStatsCache
  Log = ::Log.for(self)

  getter :cache_file_path

  def initialize(@blog : Tremolite::Blog)
    @cache_path = Tremolite::DataManager::CACHE_PATH.as(String)
    @cache_file_path = File.join([@cache_path, "nav_stats.yml"])

    @stats = NavStatsCacheObject.new
    load_cache
  end

  def refresh
    posts = @blog.post_collection.posts
    self_propelled_posts = posts.select { |post| post.self_propelled? }

    bicycle_posts = self_propelled_posts.select { |post| post.bicycle? }
    hike_posts = self_propelled_posts.select { |post| post.hike? }
    train_posts = posts.select { |post| post.train? }

    bicycle_distance = bicycle_posts.map { |post| post.distance }.compact.sum.to_i
    bicycle_time_length = bicycle_posts.map { |post| post.time_spent }.compact.sum.to_i
    bicycle_count = bicycle_posts.size

    hike_distance = hike_posts.map { |post| post.distance }.compact.sum.to_i
    hike_time_length = hike_posts.map { |post| post.time_spent }.compact.sum.to_i
    hike_count = hike_posts.size

    train_distance = train_posts.map { |post| post.distance }.compact.sum.to_i
    train_time_length = train_posts.map { |post| post.time_spent }.compact.sum.to_i
    train_count = train_posts.size

    self_distance_sum = bicycle_distance + hike_distance
    self_time_length_sum = bicycle_time_length + hike_time_length

    @stats.bicycle_distance = bicycle_distance
    @stats.bicycle_time_length = bicycle_time_length
    @stats.bicycle_count =       bicycle_count

    @stats.hike_distance =    hike_distance
    @stats.hike_time_length = hike_time_length
    @stats.hike_count =       hike_count

    @stats.train_distance =    train_distance
    @stats.train_time_length = train_time_length
    @stats.train_count =       train_count

    @stats.self_distance =    self_distance_sum
    @stats.self_time_length = self_time_length_sum

    @stats.updated_at = Time.local

    save_cache
  end

  def to_hash
    h = Hash(String, String).new
    h["nav-stats-short"] = String.build do |s|
      s << @stats.self_distance.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1 ")
      s << " km"
    end
    h["nav-stats-bicycle"] = String.build do |s|
      s << "rowerem "
      s << @stats.bicycle_distance.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1 ")
      s << " km, "
      s << @stats.bicycle_time_length.to_s
      s << " godzin"
    end
    h["nav-stats-hike"] = String.build do |s|
      s << "pieszo "
      s << @stats.hike_distance.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1 ")
      s << " km, "
      s << @stats.hike_time_length.to_s
      s << " godzin"
    end
    h["nav-stats-train"] = String.build do |s|
      s << "pociągiem "
      s << @stats.train_distance.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1 ")
      s << " km, "
      s << @stats.train_time_length.to_s
      s << " godzin"
    end
    h["current_year"] = Time.local.year.to_s

    return h
  end

  private def save_cache
    Log.debug { "save_cache" }

    File.open(cache_file_path, "w") do |f|
      @stats.to_yaml(f)
    end
  end

  private def load_cache
    if File.exists?(cache_file_path)
      Log.debug { "loading cache" }
      @stats = NavStatsCacheObject.from_yaml(File.open(cache_file_path))
    end
  end
end
