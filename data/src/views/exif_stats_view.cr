require "./helpers/exif_stats_helper"

class ExifStatsView < PageView
  def initialize(@blog : Tremolite::Blog, @url : String)

    @url = "/exif_stats"
    @title = "Statystyki EXIF"
    @subtitle = ""

    @published_photos = Array(PhotoEntity).new

    @blog.post_collection.posts.map do |post|
      post.photo_entities.not_nil!.each do |photo_entity|
        @published_photos << photo_entity.not_nil!
      end
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
    helper = ExifStatsHelper.new(
      photos: photos
    )

    helper.make_it_so

    return helper.to_html
  end
end
