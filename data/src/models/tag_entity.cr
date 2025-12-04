struct TagEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @is_nav : Bool

  getter :name, :slug, :is_nav

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @slug_pl = y["slug_pl"].to_s
    @name = y["name"].to_s
    @is_nav = y["is_nav"]?.to_s == "true"
  end

  def is_nav?
    return self.is_nav
  end

  def view_url
    "/tag/#{@slug_pl}.html"
  end

  def image_url
    File.join(["/", "images", "tag", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.tags.not_nil!.includes?(@slug)
  end
end
