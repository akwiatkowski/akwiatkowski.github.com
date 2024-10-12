require "./abstract_masonry_view"

module PostListView
  class NewPostsMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    URL   = "/tag/latest/masonry.html"
    COUNT = 20

    def initialize(
      @blog : Tremolite::Blog,
      @only_ready = true
    )
      @show_only_count = 8
      @url = URL

      sorted_posts = @blog.post_collection.posts.select do |post|
        post.finished_at
      end.sort do |a, b|
        b.finished_at.not_nil! <=> a.finished_at.not_nil!
      end

      @posts = sorted_posts[0...COUNT].as(Array(Tremolite::Post))
    end

    def title
      "Ostatnio dokończone wpisy"
    end

    # already added to array in constructor
    def post_list
      @posts
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
