require "./page_view"

# Show view for a specific area - displays area info, stats, and links
#
# URL pattern: /<type>/<slug>.html
# Example: /gminy/pobiedziska.html
class AreaShowView < PageView
  Log = ::Log.for(self)

  @posts : Array(Tremolite::Post)
  @photo_count : Int32
  @best_photo : PhotoEntity?

  def initialize(context : RenderContext, @area : AreaEntity)
    super(context: context, url: @area.show_url)
    @posts = context.posts_for_area(@area)
    @photo_count = count_photos_in_area
    @best_photo = find_best_photo
  end

  def add_to_sitemap?
    true
  end

  def title
    @area.name
  end

  def subtitle
    @area.area_type.polish_name
  end

  def image_url
    @best_photo ? @best_photo.not_nil!.full_image_src : ""
  end

  def inner_html
    String.build do |s|
      s << "<div class=\"area-info\">\n"

      # Area type badge
      s << "<p class=\"area-type-badge\">#{@area.area_type.polish_name}</p>\n"

      # Stats
      s << "<div class=\"area-stats\">\n"
      s << "<p><strong>Liczba wpisów:</strong> #{@posts.size}</p>\n"
      s << "<p><strong>Liczba zdjęć:</strong> #{@photo_count}</p>\n"
      s << "</div>\n"

      # Links to other views
      s << "<div class=\"area-links\">\n"
      s << "<a href=\"#{@area.post_list_url}\" class=\"btn\">Zobacz wpisy</a>\n"
      if @photo_count > 0
        s << "<a href=\"#{@area.gallery_url}\" class=\"btn\">Zobacz galerię</a>\n"
      end
      s << "</div>\n"

      # Recent posts preview
      if @posts.size > 0
        s << "<h2>Ostatnie wpisy</h2>\n"
        s << render_posts_preview(@posts.first(5))
      end

      s << "</div>\n"
    end
  end

  private def count_photos_in_area : Int32
    all_photos = context.posts.flat_map { |p| p.published_photo_entities }
    selector = AreaPhotoSelector.new(all_photos)
    selector.photos_in_area(@area).size
  end

  private def find_best_photo : PhotoEntity?
    all_photos = context.posts.flat_map { |p| p.published_photo_entities }
    selector = AreaPhotoSelector.new(all_photos)
    selector.best_photo_for(@area)
  end
end
