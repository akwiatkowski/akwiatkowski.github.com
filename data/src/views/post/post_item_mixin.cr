module PostItemMixin
  def render_post_box(
    post : Tremolite::Post,
    klass : String = ""
  ) : String
    ph = Hash(String, String).new
    ph["klass"] = klass
    ph["post.url"] = post.url
    ph["post.small_image_url"] = post.small_image_url.not_nil!
    ph["post.title"] = post.title
    ph["post.date"] = post.date

    if post.distance.not_nil! > 0.0
      ph["post.distance"] = "#{post.distance.not_nil!.to_i.to_s}km"
    else
      ph["post.distance"] = ""
    end

    if post.time_spent.not_nil! > 0.0
      ph["post.time_length"] = "#{post.time_spent.not_nil!.to_i.to_s}h"
    else
      ph["post.time_length"] = ""
    end

    return load_html("post/box", ph)
  end
end
