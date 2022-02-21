module GalleryView
  class IndexView < PageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @tag_gallery_index_view : TagIndexView
    )
      @url = "/gallery"
    end

    # main params of this page
    def title
      @blog.data_manager.not_nil!["gallery.subtitle"]
    end

    def title
      @blog.data_manager.not_nil!["gallery.title"]
    end

    def image_url
      @image_url ||= @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    end

    def content
      return ""
    end
  end
end
