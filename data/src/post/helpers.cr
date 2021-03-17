class Tremolite::Post
  def data_path
    return @blog.data_path.as(String)
  end

  def public_path
    return @blog.public_path.as(String)
  end

  def content_html_word_count
    self.content_html.scan(/\w+/).size
  end
end
