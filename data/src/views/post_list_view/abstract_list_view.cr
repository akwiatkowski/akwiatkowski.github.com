require "../post/post_item_mixin"

module PostListView
  class AbstractListView < BaseView
    def subtitle
      s = @posts.size
      return case s
      when 0       then "brak wpisów"
      when 1       then "1 wpis"
      when 2, 3, 4 then "#{s} wpisy, między #{time_range_string}"
      else              "#{s} wpisów, między #{time_range_string}"
      end
    end

    def time_range_string
      if @posts.size > 1
        return "#{@posts.first.date} - #{@posts.last.date}"
      else
        return ""
      end
    end

    def content
      header_html + list_html
    end

    def list_html
      content = ""
      data = Hash(String, String).new

      data["content"] = render_posts_preview(@posts)
      return load_html("page/article", data)
    end
  end
end
