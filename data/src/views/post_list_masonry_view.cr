class PostListMasonryView < BaseView
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
      ph = Hash(String, String).new
      ph["klass"] = @show_only_count >= count ? "" : "hidden"
      ph["post.url"] = post.url
      ph["post.small_image_url"] = post.small_image_url.not_nil!
      ph["post.title"] = post.title
      ph["post.date"] = post.date

      boxes += load_html("post/box", ph)
      boxes += "\n"

      count += 1
    end

    data["postbox"] = boxes
    return load_html("home", data)
  end
end
