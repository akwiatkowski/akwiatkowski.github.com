require "../markdown_page_view"

module StaticView
  # DEPRECATED: Use NewMoreView at /wiecej.html instead
  # This view is kept for backward compatibility at /wiecej2.html
  class MoreView < MarkdownPageView
    URL = "/wiecej2.html"

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
