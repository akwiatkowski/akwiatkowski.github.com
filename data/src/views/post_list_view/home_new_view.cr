module PostListView
  class HomeNewView < BaseView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @url = "/new",
    )
    end

    def content
      data = Hash(String, String).new
      return load_html("home_new", data)
    end

    def head_close_html
      data = Hash(String, String).new
      return load_html("home_new_head_close", data)
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
