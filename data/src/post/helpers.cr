class Tremolite::Post
  def data_path
    return @blog.data_path.as(String)
  end

  def output_path
    return @blog.output_path.as(String)
  end

  def content_html_word_count
    self.content_html.scan(/\w+/).size
  end

  def content_html_missing_reference_links
    self.content_html.scan(/\[\w+]/).size / 2
  end

  # vimeo players are being deprecated
  def content_html_contains_vimeo
    self.content_html.scan(/player\.vimeo/).size
  end
end
