class Tremolite::Post
  def data_path
    return @blog.data_path.as(String)
  end

  def public_path
    return @blog.public_path.as(String)
  end
end
