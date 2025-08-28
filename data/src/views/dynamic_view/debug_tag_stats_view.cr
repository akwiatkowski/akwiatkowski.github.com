module DynamicView
  class DebugTagStatsView < WiderPageView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @by_tag : String | Nil = nil,
    )
      @url = "/debug/tagged_photos"
      @title = "Otagowanie zdjęć we wpisach"
      @subtitle = "aby każde zdjęcia miało jeszcze więcej informacji"

      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
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
        s << "<th>Otagowane</th>\n"

        s << "<th>Dobre</th>\n"
        s << "<th>Najlep.</th>\n"

        s << "<th>Tagi</th>\n"
        s << "</tr>\n"

        @posts.each do |post|
          published_photos = published_photos_in_post(post)

          published_size = published_photos.size
          good_size = published_photos.select { |pe| pe.tags.includes?("good") }.size
          best_size = published_photos.select { |pe| pe.tags.includes?("best") }.size
          at_least_one_tag_size = published_photos.select { |pe| pe.tags.size > 0 }.size
          tags_string = published_photos.map { |pe| pe.tags }.flatten.sort.uniq.join(", ")

          s << "<tr>\n"
          s << "<td class=\"small\">#{post.date}</td>\n"

          # no photos
          klass = "text-danger"
          # minimum amount of photos
          klass = "text-warning" if published_size >= 2
          # good/best photos -> better
          klass = "text-success" if good_size > 0
          klass = "text-primary" if best_size > 0

          s << "<td>"
          s << "<a href=\"#{post.url}\" class=\"#{klass}\">"
          s << "#{post.title}"
          s << "</a>"
          s << "</td>\n"

          s << "<td>#{published_size > 0 ? published_size : nil}</td>\n"
          s << "<td>#{at_least_one_tag_size > 0 ? at_least_one_tag_size : nil}</td>\n"

          s << "<td>#{good_size > 0 ? good_size : nil}</td>\n"
          s << "<td>#{best_size > 0 ? best_size : nil}</td>\n"

          s << "<td>#{tags_string}</td>\n"

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
