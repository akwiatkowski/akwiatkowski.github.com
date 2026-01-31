struct LandEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @country : String
  @code : String?

  getter :name, :slug, :country, :code

  def initialize(y : YAML::Any)
    @slug = y["slug"].as_s
    @name = y["name"].as_s
    @country = y["country"].as_s
    @code = y["country"].as_s?
  end

  def type
    "" # TODO: remove it
  end

  def view_url
    "/kraina/#{@slug}.html"
  end

  def image_url
    File.join(["/", "images", "land", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.lands.not_nil!.includes?(@slug)
  end
end
