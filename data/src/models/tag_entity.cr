struct TagEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @is_nav : Bool

  getter :name, :slug, :is_nav

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s
    @is_nav = y["is_nav"]?.to_s == "true"
  end

  def is_nav?
    return self.is_nav
  end

  def list_url
    "/tag/#{@slug}"
  end

  def masonry_url
    "/tag/#{@slug}/masonry.html"
  end

  def image_url
    File.join(["/", "images", "tag", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.tags.not_nil!.includes?(@slug)
  end
end
