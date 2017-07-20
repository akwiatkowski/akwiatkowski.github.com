require "./models/poi_entity"

alias TremolitePostRouteObject = Hash(String, (String | Array(Array(Float64))))

class Tremolite::Post
  MAX_RELATED_POSTS = 5

  def custom_initialize
    @tags = Array(String).new
    @towns = Array(String).new
    @lands = Array(String).new
    @pois = Array(PoiEntity).new

    # yey, static typing
    @coords = Array(TremolitePostRouteObject).new

    @small_image_url = "/images/processed/#{slug}_small_header.jpg"
    @big_thumb_image_url = "/images/processed/#{slug}_big_thumb_header.jpg"
    @thumb_image_url = "/images/processed/#{slug}_thumb_header.jpg"

    # obsolote
    @ext_image_url = String.new

    @distance = 0.0
    @time_spent = 0.0

    # seo
    @desc = String.new
    @keywords = Array(String).new
  end

  BICYCLE_TAG = "bicycle"
  HIKE_TAG    = "hike"
  TRAIN_TAG   = "train"
  CAR_TAG     = "car"

  TODO_TAG = "todo"
  TODO_MEDIA_TAG = "todo_media"

  getter :coords
  getter :small_image_url, :thumb_image_url, :big_thumb_image_url
  getter :tags, :towns, :lands, :pois
  getter :desc, :keywords
  getter :distance, :time_spent

  def bicycle?
    self.tags.not_nil!.includes?(BICYCLE_TAG)
  end

  def hike?
    self.tags.not_nil!.includes?(HIKE_TAG)
  end

  def train?
    self.tags.not_nil!.includes?(TRAIN_TAG)
  end

  def car?
    self.tags.not_nil!.includes?(CAR_TAG)
  end

  def ready?
    return false if self.tags.not_nil!.includes?(TODO_TAG)
    # return false if self.tags.not_nil!.includes?(TODO_MEDIA_TAG)
    return true
  end

  # all other types of light walking activities with >0 distance
  def walk?
    return false if train? || car?
    return false if bicycle? || hike?

    return true if self.distance && self.distance.not_nil! > 0.0
    return false
  end

  # distance can be used in stats
  def self_propelled?
    return false if train? || car?
    return true if bicycle? || hike? || walk?
    return false
  end

  # XXX upgrade in future
  def related_posts(blog : Tremolite::Blog)
    posts = blog.post_collection.posts - [self]
    selected_posts = posts.select { |post| self.is_related_to_other_post?(post, blog) }
    sorted_posts = selected_posts.sort { |a, b| (self.time - a.time).abs <=> (self.time - b.time).abs }[0...MAX_RELATED_POSTS]
    return sorted_posts
  end

  def is_related_to_other_post?(post : Tremolite::Post, blog : Tremolite::Blog) : (Nil | Float64)
    towns = blog.data_manager.not_nil!.town_slugs.not_nil!
    if self.towns && post.towns
      self_towns = self.towns.not_nil!.select { |t| towns.includes?(t) }
      other_towns = post.towns.not_nil!.select { |t| towns.includes?(t) }

      common_size = (self_towns & other_towns).size

      return nil if 0 == common_size
      # maybe some distance calculation in future
      # one town is not enough to be related when route has more towns
      return nil if (1 == common_size) && (self_towns.size > 1) && (other_towns.size > 1)
      return 1.0
    end
    return nil
  end

  def custom_process_header
    if @header["coords"]?
      # TODO refactor to structure
      # easier to generate JSON
      coords = @header["coords"]
      coords.each do |ch|
        ro = TremolitePostRouteObject.new
        ro["type"] = ch["type"].to_s
        ro["route"] = Array(Array(Float64)).new

        ch["route"].each do |coord|
          if coord.size == 2
            ro["route"].as(Array) << [coord[0].to_s.to_f, coord[1].to_s.to_f]
          else
            @logger.error("Post #{@slug} - error in route coords")
          end
        end

        @coords.not_nil! << ro
      end
    end

    if @header["distance"]?
      @distance = @header["distance"].to_s.to_f
    end

    if @header["time_spent"]?
      @time_spent = @header["time_spent"].to_s.to_f
    end

    # tags, towns and lands
    if @header["tags"]?
      @header["tags"].each do |tag|
        @tags.not_nil! << tag.to_s
      end
    end
    if @header["towns"]?
      @header["towns"].each do |town|
        @towns.not_nil! << town.to_s
      end
    end
    if @header["lands"]?
      @header["lands"].each do |land|
        @lands.not_nil! << land.to_s
      end
    end

    # pois
    if @header["pois"]? && "" != @header["pois"]?.to_s
      @header["pois"].each do |poi|
        @pois.not_nil! << PoiEntity.new(poi)
      end
    end

    # seo keywords
    if @header["keywords"]? && "" != @header["keywords"]?.to_s
      @header["keywords"].each do |keyword|
        @keywords.not_nil! << keyword.to_s
      end
    end

    @desc = @header["desc"].to_s if @header["desc"]?

    # download previous external heade images locally
    # now we will only use local images
    @ext_image_url = @header["header-ext-img"].to_s if @header["header-ext-img"]?
    download_header_image
  end

  def related_coords : Array(Tuple(Float64, Float64))
    cs = Array(Tuple(Float64, Float64)).new

    @pois.not_nil!.each do |p|
      cs << {p.lat, p.lon}
    end

    @coords.not_nil!.each do |ce|
      ce["route"].as(Array).each do |c|
        cs << {c[0], c[1]}
      end
    end

    return cs
  end

  def closest_to_point(lat : Float64, lon : Float64)
    cs = related_coords
    cs = cs.sort { |a, b|
      da = (a[0] - lat) ** 2 + (a[1] - lon) ** 2
      db = (b[0] - lat) ** 2 + (b[1] - lon) ** 2
      da <=> db
    }

    if cs.size > 0
      return cs.last
    else
      return nil
    end
  end

  def closest_distance_to_point(lat : Float64, lon : Float64)
    p = closest_to_point(lat: lat, lon: lon)
    if p
      cp = CrystalGpx::Point.new(lat: p[0], lon: p[1])
      d = cp.distance_to(other_lat: lat, other_lon: lon)
      # puts "#{d}: #{lat}, #{lon} - #{p[0]}, #{p[1]}"
      return d
    else
      return nil
    end
  end

  # temporary download external image as title
  private def download_header_image
    img_url = File.join(["data", @image_url])
    if @ext_image_url.to_s != "" && false == File.exists?(img_url)
      ImageResizer.download_image(source: @ext_image_url.not_nil!, output: img_url)
    end
  end
end
