class PoisView < PageView
  Log = ::Log.for(self)

  def initialize(context : RenderContext, @url : String)
    super(context: context, url: @url)
    meta = context.page_meta("pois")
    @image_url = meta[:backgrounds].as(String)
    @title = meta[:title].as(String)
    @subtitle = meta[:subtitle].as(String)
  end

  getter :image_url, :title, :subtitle

  def add_to_sitemap?
    true
  end

  def inner_html
    posts_content = ""

    context.posts_from_latest.each do |post|
      pois_content = ""
      post.pois.not_nil!.each do |poi|
        pois_content += load_html("pois/poi", {
          "zoom" => 13.to_s,
          "lat"  => poi.lat.to_s,
          "lon"  => poi.lon.to_s,
          "desc" => poi.name,
        })
        pois_content += "\n"
      end

      # ignore posts without pois
      if pois_content.size > 0
        posts_content += load_html("pois/post", {
          "post.url"   => post.url,
          "post.date"  => post.date,
          "post.title" => post.title,
          "post.pois"  => pois_content,
        })
        posts_content += "\n"
      end
    end

    di = {
      "pois.content" => posts_content,
    }

    return load_html("pois/index", di)
  end
end
