module GalleryView
  class TagStatsView < WidePageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @by_tag : String | Nil = nil
    )
      @url = "/gallery/stats"
      @title = "Tagi we wpisach"
      @subtitle = ""

      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))

      # @posts.each do |post|
      #   published_photos = @blog.data_manager.exif_db.published_photo_entities(post.slug)
      #   Log.debug { "post #{post.slug} - #{published_photos.size} photos" }
      #   @published_photos += published_photos
      # end
    end

    getter :title, :subtitle
    property :url

    def inner_html
      return String.build do |s|
        s << "<table>"
        @posts.each do |post|
          published_photos = published_photos_in_post(post)

          published_size = published_photos.size
          good_size = published_photos.select { |pe| pe.tags.includes?("good") }.size
          best_size = published_photos.select { |pe| pe.tags.includes?("best") }.size

          s << "<tr>"
          s << "<td>#{post.title}</td>"
          s << "<td>#{published_size}</td>"
          s << "<td>#{good_size}</td>"
          s << "<td>#{best_size}</td>"
          s << "</tr>"
        end
        s << "</table>"
      end
    end

    private def published_photos_in_post(post)
      return @blog.data_manager.exif_db.published_photo_entities(post.slug)
    end
  end
end
