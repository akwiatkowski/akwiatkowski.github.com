require "../base_view"
require "../post/post_item_mixin"

module PostListView
  class AbstractMasonryView < BaseView
    include PostItemMixin

    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @url = "/",
      @only_ready = true
    )
      @show_only_count = 8
    end

    def content
      data = Hash(String, String).new

      boxes = ""
      count = 0

      posts = @posts.sort { |a, b| b.time <=> a.time }

      if @only_ready
        # sorted by date descending
        posts = posts.select do |post|
          # and only show finished posts
          post.ready?
        end
      end

      posts.each do |post|
        boxes += render_post_box(
          post: post,
          klass: @show_only_count >= count ? "" : "hidden"
        )
        boxes += "\n"

        count += 1
      end

      data["postbox"] = boxes
      return load_html("home", data)
    end
  end
end
