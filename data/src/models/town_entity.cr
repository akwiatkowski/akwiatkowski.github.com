require "yaml"

alias TownEntityHash = Hash(String, String | Array(String))

struct TownEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @type : String
  @header_ext_img : String?
  @header_img : String?

  @voivodeship : String?
  @lat : Float64?
  @lon : Float64?

  getter :name, :slug, :voivodeship, :header_ext_img, :header_img, :lat, :lon

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s
    @type = y["type"].to_s

    if y["header-img"]?
      @header_img = y["header-img"].to_s
    end
    if y["header-ext-img"]?
      @header_img = y["header-ext-img"].to_s
    end

    if y["inside"]?
      @voivodeship = y["inside"][0].to_s
    end

    @voivodeship = y["voivodeship"].to_s if y["voivodeship"]?
    @lat = y["lat"].to_s.to_f if y["lat"]?
    @lon = y["lon"].to_s.to_f if y["lon"]?
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
    if is_town?
      return "/town/#{@slug}"
    else
      return "/voivodeship/#{@slug}"
    end
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
      validator.error_in_object(self, "#{self.name} / #{self.voivodeship} - missing photo")
    end
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.towns.not_nil!.includes?(@slug)
  end
end
