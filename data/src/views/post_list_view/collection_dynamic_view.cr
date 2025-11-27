module PostListView
  class CollectionDynamicView < BaseView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @url : String,
      @filter_by : String = "",
      @filter_value : String = "",
    )
    end

    def content
      data = Hash(String, String).new
      data["filter_by"] = @filter_by
      data["filter_value"] = @filter_value

      return load_html("post_collection/dynamic", data)
    end

    def head_close_html
      data = Hash(String, String).new
      return load_html("post_collection/dynamic_head", data)
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
