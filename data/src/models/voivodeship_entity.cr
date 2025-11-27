require "yaml"

struct VoivodeshipEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @type : String?
  @country : String?
  @header_img : String?
  @border_top_left_lat : Float64?
  @border_top_left_lon : Float64?
  @border_bottom_right_lat : Float64?
  @border_bottom_right_lon : Float64?

  getter :name, :slug, :header_img, :country
  getter :border_top_left_lat, :border_top_left_lon,
    :border_bottom_right_lat, :border_bottom_right_lon

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s

    if y["header-img"]?
      @header_img = y["header-img"].to_s
    end

    if y["country"]?
      @country = y["country"].to_s.strip
    end

    if y["border_top_left"]?
      @border_top_left_lat = y["border_top_left"][0].to_s.to_f
      @border_top_left_lon = y["border_top_left"][1].to_s.to_f
    end

    if y["border_bottom_right"]?
      @border_bottom_right_lat = y["border_bottom_right"][0].to_s.to_f
      @border_bottom_right_lon = y["border_bottom_right"][1].to_s.to_f
    end
  end

  def to_hash
    h = TownEntityHash.new
    unless @slug.nil?
      h["slug"] = @slug.to_s
      h["url"] = self.view_url
    end
    h["name"] = @name.to_s unless @name.nil?
    h["type"] = @type.to_s unless @type.nil?

    return h
  end

  def is_town?
    return @type == "town"
  end

  def is_voivodeship?
    return @type == "voivodeship"
  end

  def is_poland?
    return @country == "Polska"
  end

  def view_url
    return "/voivodeship/#{@slug}.html"
  end

  def list_url
    return "/voivodeship/#{@slug}/list.html"
  end

  def masonry_url
    return "/voivodeship/#{@slug}/masonry.html"
  end

  def image_url
    File.join(["/", relative_image_url])
  end

  def relative_image_url
    File.join(["images", "town", @slug + ".jpg"])
  end

  def validate(validator : Tremolite::Validator)
    data_image_path = File.join(validator.blog.data_path, relative_image_url)
    unless File.exists?(data_image_path)
      validator.error_in_object(self, "#{self.name} - missing photo")
    end
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.voivodeships.not_nil!.includes?(@slug)
  end
end
