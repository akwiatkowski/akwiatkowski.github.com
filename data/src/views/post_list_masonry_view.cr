require "./post/post_item_mixin"

class PostListMasonryView < BaseView
  include PostItemMixin

  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @url = "/")
    @show_only_count = 8
  end

  # only non-todo, and main tagged posts
  def post_list
    @blog.post_collection.posts.select { |p| (p.tags.not_nil!.includes?("todo") == false) && (p.tags.not_nil!.includes?("main") == true) }
  end

  def content
    data = Hash(String, String).new

    boxes = ""
    count = 0

    # sorted by date descending
    posts = post_list.sort { |a, b| b.time <=> a.time }.select do |post|
      # and only show finished posts
      post.ready?
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
