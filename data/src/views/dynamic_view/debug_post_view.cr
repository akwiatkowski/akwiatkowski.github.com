module DynamicView
  class DebugPostView < WidePageView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog)
      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
      @image_url = generate_image_url.as(String)
      @title = "Które wpisy są gotowe?"
      @subtitle = ""
      @url = "/debug/posts"
    end

    getter :image_url, :title, :subtitle
    property :url

    def inner_html
      return String.build do |s|
        s << "<table class=\"table\">"

        s << "<tr>"
        s << "<th></th>"
        TABLE_HEADERS.values.each do |header_title|
          s << "<th>#{header_title}</th>"
        end
        s << "</tr>"

        # filter by severity of lack of readiness of post
        # and then coeff
        post_readiness = @posts.map{|post| post_readiness_tuple(post) }.sort do |a,b|
          css_int_comp = a[:css_int] <=> b[:css_int]
          coeff_comp = a[:coeff] <=> b[:coeff]

          if css_int_comp == 0
            coeff_comp
          else
            css_int_comp
          end
        end

        post_readiness.each_with_index do |tuple, i|

          s << "<tr class=\"#{tuple[:css]}\">"
          s << "<td>#{i+1}</td>"
          TABLE_HEADERS.keys.each do |key|
            value = tuple[key]

            if value.to_s == true.to_s
              value_string = "&check;"
            elsif value.to_s == false.to_s
              value_string = "&cross;"
            else
              value_string = value.to_s
            end

            if key == :title
              url = tuple[:post].url
              value_string = "<a href=\"#{url}\" class=\"#{tuple[:css]}\">#{value_string}</a>"
            end

            s << "<td>#{value_string}</td>"
          end
          s << "</tr>"

        end
        s << "</table>"
      end
    end

    TABLE_HEADERS = {
      title: "Tytuł",
      ready: "Ukończony",
      text_included: "Tekst",
      all_references: "Referencje",
      has_land: "Krainy",
      photo_count: "Zdjęcia",
      coeff: "Ocena"
    }

    def post_readiness_tuple(post)
      i = 0
      i += 100 if post.ready?
      i += Math.sqrt(post.content_html_word_count).to_i
      i += post.published_photo_entities.size

      # TODO add town count

      lands_count = post.lands.not_nil!.size

      if post.content_html_word_count < 50
        # small word - red, a lot of work
        css = "text-danger" # red
        css_int = 0

      elsif post.content_html_word_count < 200
        # has few words, but not enough
        css = "text-warning" # yellow
        css_int = 1

      elsif post.content_html_missing_reference_links > 0
        # missing referenes, some work needed
        css = "text-warning" # yellow
        css_int = 1

      elsif post.published_photo_entities.size <= 1
        # no photos, some work needed
        css = "text-warning" # yellow
        css_int = 1

      elsif post.ready? == false
        # not ready, minor work needed
        css = "text-success" # green
        css_int = 5

      elsif post.content_html_contains_vimeo > 0
        # vimeo player is going deprecated
        css = "text-success" # green
        css_int = 5

      elsif lands_count == 0
        # no lands, need to add some
        css = "text-success" # green
        css_int = 5
        
      elsif post.ready?
        # it's ready, no work needed
        css = "text-primary" # blue
        css_int = 10

      else
        # error
        css = "text-secondary"
        css_int = 100

      end

      return {
        post: post,
        text_included: post.content_html_word_count > 50,
        all_references: post.content_html_missing_reference_links == 0,
        contains_vimeo: post.content_html_contains_vimeo > 0,
        ready: post.ready?,
        title: post.title,
        photo_count: post.published_photo_entities.size,
        word_count: post.content_html_word_count,
        missing_references_count: post.content_html_missing_reference_links,
        lands_count: lands_count,
        has_land: lands_count > 0,
        coeff: i.to_i,
        css: css,
        css_int: css_int
      }
    end

    private def generate_image_url
      return @posts.last.image_url
    end
  end
end
