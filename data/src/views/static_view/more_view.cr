require "../markdown_page_view"

module StaticView
  class MoreView < MarkdownPageView
    URL = "/wiecej.html"

    Log = ::Log.for(self)

    def initialize(context : RenderContext)
      meta = context.page_meta("more")
      super(
        context: context,
        url: URL,
        file: "more",
        image_url: meta[:backgrounds].as(String),
        title: meta[:title].as(String),
        subtitle: meta[:subtitle].as(String)
      )
    end

    def add_to_sitemap?
      false
    end
  end
end
