struct NavStatsCacheObject
  include YAML::Serializable

  struct EntityNavTuple
    include YAML::Serializable

    @name : String = ""
    @url : String = ""
    @count : Int32 = 0

    property :name, :url, :count

    def initialize(@name, @url, @count)
    end
  end

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

  @voivodeships_nav : Array(EntityNavTuple) = Array(EntityNavTuple).new
  @lands_nav : Array(EntityNavTuple) = Array(EntityNavTuple).new
  @tags_nav : Array(EntityNavTuple) = Array(EntityNavTuple).new

  property :bicycle_distance, :bicycle_time_length, :bicycle_count,
    :hike_distance, :hike_time_length, :hike_count,
    :train_distance, :train_time_length, :train_count,
    :self_distance, :self_time_length,
    :updated_at,
    :voivodeships_nav, :lands_nav, :tags_nav

  def initialize
  end
end

class NavStatsCache
  Log = ::Log.for(self)

  getter :cache_file_path, :stats

  def initialize(
    @blog : Tremolite::Blog,
  )
    @cache_path = @blog.cache_path.as(String)
    @cache_file_path = File.join([@cache_path, "nav_stats.yml"])

    @stats = NavStatsCacheObject.new
    load_cache
  end

  def posts
    @blog.post_collection.posts.as(Array(Tremolite::Post))
  end

  def refresh
    refresh_voivodeships_nav
    refresh_lands_nav
    refresh_tags_nav

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
    @stats.bicycle_count = bicycle_count

    @stats.hike_distance = hike_distance
    @stats.hike_time_length = hike_time_length
    @stats.hike_count = hike_count

    @stats.train_distance = train_distance
    @stats.train_time_length = train_time_length
    @stats.train_count = train_count

    @stats.self_distance = self_distance_sum
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

  private def process_model_array_to_nav(
    model_array : Array,
    ignore_less_than = 1,
    perform_sort = true,
  )
    nav_array = Array(NavStatsCacheObject::EntityNavTuple).new

    model_array.each do |model|
      count = posts.select { |post| post.was_in?(model) && post.ready? }.size

      if count >= ignore_less_than
        nav_array << NavStatsCacheObject::EntityNavTuple.new(
          name: model.name,
          url: model.view_url,
          count: count,
        )
      end
    end

    if perform_sort
      nav_array = nav_array.sort do |a, b|
        b.count <=> a.count
      end
    end

    return nav_array
  end

  private def refresh_voivodeships_nav
    voivodeships = @blog.data_manager.voivodeships.not_nil!.select { |v| v.is_poland? }

    @stats.voivodeships_nav = process_model_array_to_nav(
      model_array: voivodeships,
      ignore_less_than: 2,
      perform_sort: false
    )
  end

  private def refresh_lands_nav
    lands = @blog.data_manager.lands.not_nil!

    @stats.lands_nav = process_model_array_to_nav(
      model_array: lands,
      ignore_less_than: 4,
      perform_sort: true
    )
  end

  private def refresh_tags_nav
    tags = @blog.data_manager.tags.not_nil!.select { |tag| tag.is_nav? }

    @stats.tags_nav = process_model_array_to_nav(
      model_array: tags,
      ignore_less_than: 2,
      perform_sort: false
    )
  end

  private def save_cache
    Log.debug { "save_cache" }

    Dir.mkdir_p(@cache_path)

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
