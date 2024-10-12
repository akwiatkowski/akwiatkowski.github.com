require "./abstract_list_view"

module PostListView
  class NewPostsView < AbstractListView
    Log = ::Log.for(self)

    URL   = "/tag/latest"
    COUNT = 20

    def initialize(@blog : Tremolite::Blog)
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

    def image_url
      if @posts.size > 0
        return @posts[0].image_url
      else
        return ""
      end
    end
  end
end
