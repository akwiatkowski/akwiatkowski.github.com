require "./post_list_masonry_view"

class HomeView < PostListMasonryView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @url = "/")
    @show_only_count = 8
  end

  def title
    @blog.data_manager.not_nil!["site.title"]
  end

  def meta_keywords_string
    "turystyka, rower, zwiedzanie, Polska, trasa, góry, odkryj, szlak, okolica, wieś, zdjęcia, fotografia, krajobraz"
  end

  def meta_description_string
    site_desc
  end

  def page_desc
    site_desc
  end
end
