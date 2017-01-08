class Tremolite::Views::BaseView
  def custom_process_function(
      command : String,
      string : String,
      post : (Tremolite::Post | Nil)
    )

    result = command.scan(/post_image\s+(\S+)\s+(\S+)/)
    if result.size > 0 && post
      size = result[0][1]
      image = result[0][2]

      string_from = result[0][0]
      string_to = post_image(post: post, size: size, image: image)

      string = string.gsub(string_from, string_to)
    end

    return string
  end

  def post_image(post : Tremolite::Post, size : String, image : String)
    return "IMAGE #{size} #{image} #{post.slug}"
  end
end
