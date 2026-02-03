require "./collection_dynamic_view"

module PostListView
  class NewPostsDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    URL   = "/tag/najnowsze.html"
    COUNT = 20

    def initialize(context : RenderContext, @only_ready = true)
      sorted_posts = context.posts.select do |post|
        post.finished_at
      end.sort do |a, b|
        b.finished_at.not_nil! <=> a.finished_at.not_nil!
      end

      @posts = sorted_posts[0...COUNT].as(Array(Tremolite::Post))

      super(
        context: context,
        url: URL,
        filter_by: "slugs",
        filter_value: @posts.map { |post| "'#{post.slug}'" }.join(",")
      )
    end

    def render_date
      return :finished
    end

    def title
      "Ostatnio dokończone wpisy"
    end

    def image_url
      if @posts.size > 0
        return @posts[0].image_url
      else
        return ""
      end
    end
  end
end
