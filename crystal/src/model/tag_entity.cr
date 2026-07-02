struct TagEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @is_nav : Bool

  getter :name, :slug, :slug_pl, :is_nav

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
    "/wpisy-dla/tagu/#{@slug_pl}.html"
  end

  # Old URL for redirect (temporary redirect to view_url)
  def legacy_url
    "/tag/#{@slug_pl}.html"
  end

  def image_url
    File.join(["/", "images", "tag", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.tag_slugs.includes?(@slug)
  end
end
