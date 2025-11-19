require "./abstract_masonry_view"

module PostListView
  class HomeMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @url = "/",
    )
      @show_only_count = 8
      @only_ready = true

      @posts = @blog.post_collection.posts.select do |p|
        (p.tags.not_nil!.includes?("todo") == false) && (p.tags.not_nil!.includes?("main") == true)
      end.as(Array(Tremolite::Post))
    end

    def title
      @blog.data_manager.not_nil!["home.title"]
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
end
