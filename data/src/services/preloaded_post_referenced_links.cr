class PreloadedPostReferencedLinks
  def initialize(@blog : Tremolite::Blog)
    @html_buffer = @blog.html_buffer.as(Tremolite::HtmlBuffer)
  end

  def populate_referenced_links
    @blog.post_collection.as(Tremolite::PostCollection).each_post_file do |post_file|
      process_file(post_file)
    end
  end

  private def process_file(file_path)
    post_slug = File.basename(file_path).gsub(File.extname(file_path), "")

    content = File.read(file_path)
    content.each_line do |line|
      res = line.scan(Markdown::Parser::ADD_REFERENCE_LINE_REGEXP)
      if res.size > 0
        match = res[0]
        if match.as?(Regex::MatchData) && false == match[1].blank? && false == match[2].blank?
          key = match[1].to_s
          url = match[2].to_s

          @html_buffer.store_referenced_link(
            key: key,
            url: url,
            post_slug: post_slug
          )
        end
      end
    end
  end
end
