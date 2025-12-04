struct PhotoTagEntity
  Log = ::Log.for(self)

  @slug : String
  @slug_pl : String
  @title : String
  @subtitle : String?

  getter :slug, :slug_pl, :title, :subtitle

  def initialize(y : YAML::Any)
    @slug = y["slug"].as_s
    @slug_pl = y["slug_pl"].as_s
    @title = y["title"].as_s
    @subtitle = y["subtitle"].as_s?
  end

  def view_url
    "/galeria/tag/#{@slug_pl}.html"
  end
end
