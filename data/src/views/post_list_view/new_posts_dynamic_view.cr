require "./collection_dynamic_view"

module PostListView
  class NewPostsDynamicView < CollectionDynamicView
    Log = ::Log.for(self)

    URL   = "/tag/najnowsze.html"
    COUNT = PostListView::NewPostsView::COUNT

    def initialize(@blog : Tremolite::Blog, @only_ready = true)
      sorted_posts = @blog.post_collection.posts.select do |post|
        post.finished_at
      end.sort do |a, b|
        b.finished_at.not_nil! <=> a.finished_at.not_nil!
      end

      @posts = sorted_posts[0...COUNT].as(Array(Tremolite::Post))

      @filter_by = "slugs"
      @filter_value = @posts.map { |post| "'#{post.slug}'" }.join(",")
      @url = URL
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
