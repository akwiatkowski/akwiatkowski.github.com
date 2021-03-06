require "xml"

module SpecialView
  class RssGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @posts : Array(Tremolite::Post),
      @site_title : String,
      @site_url : String,
      @site_desc : String,
      @url : String = "/feed.xml",
      @site_language : (String | Nil) = nil,
      @site_webmaster : (String | Nil) = nil,
      @updated_at : (Time) = Time.local
    )
    end

    getter :url

    def output
      to_xml
    end

    def to_xml
      content
    end

    def content
      s = "<?xml version=\"1.0\"?>\n"
      s += "<rss version=\"2.0\">\n"
      s += rss_channel
      s += rss_posts
      s += "</rss>\n"
      return s
    end

    def rss_channel
      s = "<channel>\n"
      s += rss_header
      s += "</channel>\n"
    end

    def rss_header
      s = "<title>#{@site_title}</title>
      <link>#{@site_url}</link>
      <description>#{@site_desc}</description>
      <lastBuildDate>#{@updated_at.to_s}</lastBuildDate>
      "
      s += rss_header_language
      s += rss_header_webmaster
      return s
    end

    def rss_header_language
      if @site_language.nil?
        return ""
      else
        return "<language>#{@site_language}</language>\n"
      end
    end

    def rss_header_webmaster
      if @site_webmaster.nil?
        return ""
      else
        return "<webMaster>#{@site_webmaster}</webMaster>\n"
      end
    end

    def rss_posts
      s = ""
      @posts.each do |post|
        s += rss_post(post) if post.ready?
      end
      return s
    end

    def rss_post(post : Tremolite::Post)
      s = "<item>\n"
      s += "<title>#{post.title}</title>\n"
      s += "<link>#{@site_url}#{post.url}</link>\n"
      s += "<description>#{post.subtitle}</description>\n"
      s += rss_post_image(post)
      s += "</item>\n"

      return s
    end

    def rss_post_image(post : Tremolite::Post)
      # TODO later
      s = ""
      # s += "<enclosure url="http://example.com/file.mp3" length="123456789" type="audio/mpeg" />"
      return s
    end
  end
end
