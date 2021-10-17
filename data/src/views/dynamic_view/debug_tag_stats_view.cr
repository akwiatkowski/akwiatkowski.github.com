module DynamicView
  class DebugTagStatsView < WiderPageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @by_tag : String | Nil = nil
    )
      @url = "/debug/tagged_photos"
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
        s << "<table class=\".table-sm\">\n"

        s << "<tr>\n"
        s << "<th>Data</th>\n"
        s << "<th>Tytuł</th>\n"
        s << "<th>Zdj.</th>\n"
        s << "<th>Dobre</th>\n"
        s << "<th>Najlep.</th>\n"
        s << "</tr>\n"

        @posts.each do |post|
          published_photos = published_photos_in_post(post)

          published_size = published_photos.size
          good_size = published_photos.select { |pe| pe.tags.includes?("good") }.size
          best_size = published_photos.select { |pe| pe.tags.includes?("best") }.size

          s << "<tr>\n"
          s << "<td class=\"small\">#{post.date}</td>\n"

          # no photos
          klass = "text-danger"
          # minimum amount of photos
          klass = "text-warning" if published_size >= 2
          # good/best photos -> better
          klass = "text-success" if good_size > 0
          klass = "text-primary" if best_size > 0

          s << "<td class=\"#{klass}\">"

          s << "#{post.title}"
          s << "<a href=\"#{post.url}\">"
          s << "↑"
          s << "</a>"

          s << "</td>\n"

          s << "<td>#{published_size > 0 ? published_size : nil}</td>\n"
          s << "<td>#{good_size > 0 ? good_size : nil}</td>\n"
          s << "<td>#{best_size > 0 ? good_size : nil}</td>\n"
          s << "</tr>\n"
        end
        s << "</table>\n"
      end
    end

    private def published_photos_in_post(post)
      return @blog.data_manager.exif_db.published_photo_entities(post.slug)
    end
  end
end
