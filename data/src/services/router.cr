# Router - Centralized URL generation with alias support
#
# This service provides all URL generation in one place, making it easy to:
# - Change URL patterns without hunting through the codebase
# - Use semantic aliases (e.g., "area_link" can point to show, post_list, or gallery)
# - Control which page type is used in different contexts via aliases
#
# Usage:
#   router = Router.new
#   router.area_show_url(area)       # Direct: /gmina/pobiedziska.html
#   router.area_link_url(area)       # Aliased: controlled by ALIASES config
#   router.post_url(post)            # /2024/01/01/post-slug/
#
# JSON serializers should use semantic names like `area_link_url` so the
# actual destination can be controlled by changing ALIASES, not JSON code.
#
class Router
  Log = ::Log.for(self)

  # Alias targets for semantic URL methods
  enum AreaLinkTarget
    Show
    PostList
    Gallery
  end

  enum TagLinkTarget
    Show
    Gallery
  end

  # ============================================
  # Alias Configuration
  # ============================================
  #
  # Change these to control which page semantic URLs point to.
  # For example, area_link_url returns show_url by default,
  # but can be changed to post_list_url by setting AREA_LINK_TARGET.
  #
  AREA_LINK_TARGET = AreaLinkTarget::Show
  TAG_LINK_TARGET  = TagLinkTarget::Show

  # ============================================
  # Area URLs (unified AreaEntity system)
  # ============================================

  # Show page: /gmina/pobiedziska.html (nominative case)
  def area_show_url(area : AreaEntity) : String
    "#{area.area_type.url_prefix}#{area.slug}.html"
  end

  # Post list page: /wpisy-dla/gminy/pobiedziska.html (genitive case)
  def area_post_list_url(area : AreaEntity) : String
    "/wpisy-dla/#{area.area_type.url_type}/#{area.slug}.html"
  end

  # Gallery page: /galeria/gminy/pobiedziska.html (genitive case)
  def area_gallery_url(area : AreaEntity) : String
    "/galeria/#{area.area_type.url_type}/#{area.slug}.html"
  end

  # Semantic alias - the URL to use when linking to an area
  # Change AREA_LINK_TARGET to control which page this points to
  def area_link_url(area : AreaEntity) : String
    case AREA_LINK_TARGET
    when AreaLinkTarget::Show     then area_show_url(area)
    when AreaLinkTarget::PostList then area_post_list_url(area)
    when AreaLinkTarget::Gallery  then area_gallery_url(area)
    else                               area_show_url(area)
    end
  end

  # Convenience method using AreaType and slug
  def area_show_url(type : AreaType, slug : String) : String
    "#{type.url_prefix}#{slug}.html"
  end

  def area_post_list_url(type : AreaType, slug : String) : String
    "/wpisy-dla/#{type.url_type}/#{slug}.html"
  end

  def area_gallery_url(type : AreaType, slug : String) : String
    "/galeria/#{type.url_type}/#{slug}.html"
  end

  # ============================================
  # Tag URLs
  # ============================================

  # Show page: /tag/rowery.html
  def tag_show_url(tag : TagEntity) : String
    "/tag/#{tag.slug}.html"
  end

  def tag_show_url(slug : String) : String
    "/tag/#{slug}.html"
  end

  # Gallery page: /galeria/tag/rowery.html
  def tag_gallery_url(tag : TagEntity) : String
    "/galeria/tag/#{tag.slug}.html"
  end

  def tag_gallery_url(slug : String) : String
    "/galeria/tag/#{slug}.html"
  end

  # Post list page: /wpisy-dla/tag/rowery.html
  def tag_post_list_url(tag : TagEntity) : String
    "/wpisy-dla/tag/#{tag.slug}.html"
  end

  def tag_post_list_url(slug : String) : String
    "/wpisy-dla/tag/#{slug}.html"
  end

  # Semantic alias - the URL to use when linking to a tag
  def tag_link_url(tag : TagEntity) : String
    case TAG_LINK_TARGET
    when TagLinkTarget::Show    then tag_show_url(tag)
    when TagLinkTarget::Gallery then tag_gallery_url(tag)
    else                             tag_show_url(tag)
    end
  end

  # ============================================
  # Post URLs
  # ============================================

  # Article page: /2024/01/01/post-slug/
  def post_url(post) : String
    post.url
  end

  # Gallery page: /2024/01/01/post-slug/galeria.html
  def post_gallery_url(post) : String
    "#{post.url}galeria.html"
  end

  # Gallery stats page: /2024/01/01/post-slug/galeria-statystyki.html
  def post_gallery_stats_url(post) : String
    "#{post.url}galeria-statystyki.html"
  end

  # Image URL: /images/2024/01/01/post-slug/image.jpg
  def post_image_url(post, size_prefix : String = "") : String
    if size_prefix.empty?
      "#{post.images_dir_url}/#{post.image_filename}"
    else
      "#{post.images_dir_url}/#{size_prefix}-#{post.image_filename}"
    end
  end

  # ============================================
  # Static Page URLs
  # ============================================

  def home_url : String
    "/"
  end

  def map_url : String
    "/map.html"
  end

  def summary_url : String
    "/summary.html"
  end

  def about_url : String
    "/about.html"
  end

  def year_report_url(year : Int32) : String
    "/year-#{year}.html"
  end

  # ============================================
  # Feed URLs
  # ============================================

  def rss_url : String
    "/feed.rss"
  end

  def atom_url : String
    "/feed.atom"
  end

  def feed_json_url : String
    "/feed.json"
  end

  def sitemap_url : String
    "/sitemap.xml"
  end

  def payload_url : String
    "/payload.json"
  end

  # ============================================
  # Gallery URLs
  # ============================================

  # Gallery for area: /galeria/gminy/pobiedziska.html
  def gallery_area_url(area : AreaEntity) : String
    area_gallery_url(area)
  end

  # Gallery for tag: /galeria/tag/rowery.html
  def gallery_tag_url(tag : TagEntity) : String
    tag_gallery_url(tag)
  end

  # ============================================
  # Index Page URLs
  # ============================================

  def tags_index_url : String
    "/tagi.html"
  end

  def towns_index_url : String
    "/gminy.html"
  end

  def voivodeships_index_url : String
    "/wojewodztwa.html"
  end

  def lands_index_url : String
    "/krainy.html"
  end

  def meso_regions_index_url : String
    "/regiony.html"
  end

  def macro_regions_index_url : String
    "/obszary.html"
  end

  # ============================================
  # Legacy Entity URLs (DEPRECATED)
  # ============================================
  # These exist for backward compatibility with old entity classes.
  # New code should use the area_* methods instead.

  def town_view_url(slug : String) : String
    area_show_url(AreaType::Town, slug)
  end

  def voivodeship_view_url(slug : String) : String
    area_show_url(AreaType::Voivodeship, slug)
  end

  def land_view_url(slug : String) : String
    area_show_url(AreaType::MesoRegion, slug)
  end
end
