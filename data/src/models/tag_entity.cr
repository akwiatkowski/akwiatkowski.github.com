struct TagEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String

  getter :name, :slug

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s
  end

  def url
    "/tag/#{@slug}"
  end

  def image_url
    File.join(["/", "images", "tag", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.tags.not_nil!.includes?(@slug)
  end
end
