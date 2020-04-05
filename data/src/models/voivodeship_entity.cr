require "yaml"

struct VoivodeshipEntity
  @slug : String
  @name : String
  @header_img : (String | Nil)
  @border_top_left_lat : Float64?
  @border_top_left_lon : Float64?
  @border_bottom_right_lat : Float64?
  @border_bottom_right_lon : Float64?

  getter :name, :slug, :header_img
  getter :border_top_left_lat, :border_top_left_lon,
    :border_bottom_right_lat, :border_bottom_right_lon

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s

    if y["header-img"]?
      @header_img = y["header-img"].to_s
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
    h["slug"] = @slug.to_s unless @slug.nil?
    h["name"] = @name.to_s unless @name.nil?
    h["header-ext-img"] = @header_ext_img.to_s unless @header_ext_img.nil?
    h["type"] = @type.to_s unless @type.nil?
    h["voivodeship"] = @voivodeship.to_s unless @voivodeship.nil?

    return h
  end

  def is_town?
    return @type == "town"
  end

  def is_voivodeship?
    return @type == "voivodeship"
  end

  def url
    return "/voivodeship/#{@slug}"
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
