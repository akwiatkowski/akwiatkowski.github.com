require "../../services/exif_stat/exif_stat_helper"

# TODO:
# * what lenses do I use on what trips: hike, bicycle, photo
# * do I use most often per post
# * what is most important?
# * what extreme focals are used?
# * filter only zoom lenses

module DynamicView
  class ExifStatsView < WidePageView
    Log = ::Log.for(self)

    # a bit internal at this moment
    def add_to_sitemap?
      return false
    end

    def initialize(
      @blog : Tremolite::Blog,
      @url : String,
      @by_tag : String | Nil = nil
    )
      @url = "/exif_stats"
      @title = "Statystyki EXIF"
      @subtitle = ""

      @published_photos = Array(PhotoEntity).new
      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))

      # filter by tag
      if @by_tag
        # TODO this should be moved elsewhere and not modified
        @url = "#{@url}/#{@by_tag}"
        @subtitle = @by_tag.not_nil!

        # filter posts
        @posts = @posts.select do |post|
          post.tags.not_nil!.includes?(@by_tag.not_nil!)
        end
      end

      @posts.each do |post|
        published_photos = @blog.data_manager.exif_db.published_photo_entities(post.slug)
        Log.debug { "post #{post.slug} - #{published_photos.size} photos" }
        @published_photos += published_photos
      end
    end

    getter :title, :subtitle
    property :url

    def inner_html
      return stats_html_for(@published_photos)
    end

    # # overriden here
    # def page_desc
    #   return @post.desc.not_nil!
    # end
    #
    # # overriden here
    # def meta_keywords_string
    #   return @post.keywords.not_nil!.join(", ").as(String)
    # end

    def stats_html_for(photos : Array(PhotoEntity))
      helper = ExifStatHelper.new(
        # posts: @post,
        photos: @published_photos
      )

      helper.make_it_so

      return helper.render_overall_stats
    end
  end
end
