struct LandEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @header_ext_img : (String | Nil)
  @header_img : (String | Nil)
  @main : String
  @country : String
  @type : String
  @visited : (Time | Nil)
  @train_time_poznan : (Int32 | Nil)
  @near : Array(String)

  getter :name, :slug, :main, :header_ext_img, :header_img, :country, :type, :visited, :train_time_poznan

  def initialize(y : YAML::Any)
    @slug = y["slug"].to_s
    @name = y["name"].to_s
    if y["header_img"]?
      @header_img = y["header_img"].to_s
    end
    @main = y["main"].to_s
    @country = y["country"].to_s
    @type = y["type"].to_s

    if y["train_time_poznan"]?
      @train_time_poznan = y["train_time_poznan"].to_s.to_i
    end

    @near = Array(String).new
    if y["near"]?
      y["near"].as_a.each do |n|
        @near << n.to_s
      end
    end
    if y["visited"]?
      @visited = Time.parse(
        time: y["visited"].to_s,
        pattern: "%Y-%m",
        location: Time::Location.load_local
      )
    end
  end

  def view_url
    "/land/#{@slug}.html"
  end

  def list_url
    "/land/#{@slug}/list.html"
  end

  def masonry_url
    "/land/#{@slug}/masonry.html"
  end

  def image_url
    File.join(["/", "images", "land", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.lands.not_nil!.includes?(@slug)
  end
end
