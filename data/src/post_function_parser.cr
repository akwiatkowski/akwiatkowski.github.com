class Tremolite::Views::BaseView
  def custom_process_function(
      command : String,
      string : String,
      post : (Tremolite::Post | Nil)
    ) : (String | Nil)

    result = command.scan(/post_image\s+\"([^\"]+)\",\"([^\"]+)\",\"([^\"]+)\"/)
    if result.size > 0 && post
      return post_image(
        post: post,
        size: result[0][1],
        image: result[0][2],
        alt: result[0][3]
      )
    end

    return nil
  end

  def post_image(post : Tremolite::Post, size : String, image : String, alt : String)
    url = "/images/processed/#{post.slug}_#{size}_#{image}"
    data = {
      "img.src" => url,
      "img.alt" => alt,
      "img.size" => (image_size(url) / 1024).to_s + " kB",
      "img_full.src" => "/images/#{post.slug}/#{image}"
    }
    return load_html("post/post_image_partial", data)
  end

  def public_path
    @blog.public_path.as(String)
  end

  def image_size(url)
    File.size(File.join([public_path, url]))
  end
end
