class Tremolite::Post
  def data_path
    return @data_path
  end

  def output_path
    return @output_path
  end

  def content_html_word_count
    self.content_html.scan(/\w+/).size
  end

  def content_html_reference_pattern_count
    self.content_html.scan(/\[\w+]/).size / 2
  end

  # vimeo players are being deprecated
  def content_html_contains_vimeo
    self.content_html.scan(/player\.vimeo/).size
  end
end
