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
  # Area URL Building Blocks
  # ============================================
  #
  # These methods centralize URL pattern knowledge.
  # AreaType provides nominative_slug (gmina) and genitive_slug (gminy).
  #

  # URL prefix for show pages: /gmina/, /powiat/, /wojewodztwo/
  def area_type_prefix(type : AreaType) : String
    "/#{type.nominative_slug}/"
  end

  # URL segment for post list/gallery: gminy, powiatu, wojewodztwa
  def area_type_segment(type : AreaType) : String
    type.genitive_slug
  end

  # ============================================
  # Area URLs (unified AreaEntity system)
  # ============================================

  # Show page: /gmina/pobiedziska.html (nominative case)
  # External areas: /zagranica/praga.html
  def area_show_url(area : AreaEntity) : String
    if area.external?
      external_area_show_url(area)
    else
      "#{area_type_prefix(area.area_type)}#{area.slug}.html"
    end
  end

  # Post list page: /wpisy-dla/gminy/pobiedziska.html (genitive case)
  # External areas: /wpisy-dla/zagranica/praga.html
  def area_post_list_url(area : AreaEntity) : String
    if area.external?
      external_area_post_list_url(area)
    else
      "/wpisy-dla/#{area_type_segment(area.area_type)}/#{area.slug}.html"
    end
  end

  # Gallery page: /galeria/gminy/pobiedziska.html (genitive case)
  # Note: External areas don't have gallery pages (for now)
  def area_gallery_url(area : AreaEntity) : String
    "/galeria/#{area_type_segment(area.area_type)}/#{area.slug}.html"
  end

  # ============================================
  # External Area URLs (/zagranica/)
  # ============================================

  # Show page: /zagranica/praga.html
  def external_area_show_url(area : AreaEntity) : String
    "/zagranica/#{area.slug}.html"
  end

  # Post list page: /wpisy-dla/zagranica/praga.html
  def external_area_post_list_url(area : AreaEntity) : String
    "/wpisy-dla/zagranica/#{area.slug}.html"
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
    "#{area_type_prefix(type)}#{slug}.html"
  end

  def area_post_list_url(type : AreaType, slug : String) : String
    "/wpisy-dla/#{area_type_segment(type)}/#{slug}.html"
  end

  def area_gallery_url(type : AreaType, slug : String) : String
    "/galeria/#{area_type_segment(type)}/#{slug}.html"
  end

  # ============================================
  # Tag URLs
  # ============================================

  # Show page: /tag/rowerem.html (uses Polish slug)
  def tag_show_url(tag : TagEntity) : String
    tag_show_url(tag.slug_pl)
  end

  def tag_show_url(slug_pl : String) : String
    "/tag/#{slug_pl}.html"
  end

  # Gallery page: /galeria/tag/rowerem.html (uses Polish slug)
  def tag_gallery_url(tag : TagEntity) : String
    tag_gallery_url(tag.slug_pl)
  end

  def tag_gallery_url(slug_pl : String) : String
    "/galeria/tag/#{slug_pl}.html"
  end

  # Post list page: /wpisy-dla/tag/rowerem.html (uses Polish slug)
  def tag_post_list_url(tag : TagEntity) : String
    tag_post_list_url(tag.slug_pl)
  end

  def tag_post_list_url(slug_pl : String) : String
    "/wpisy-dla/tagu/#{slug_pl}.html"
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
  #
  # Post URL structure: /YYYY/MM/slug.html
  # Built from time components and slug, not by concatenating post.url
  #

  # Article page: /2024/01/slug.html
  def post_url(year : Int32, month : Int32, slug : String) : String
    "/#{year}/#{"%.2d" % month}/#{slug}.html"
  end

  def post_url(post) : String
    post_url(post.time.year, post.time.month, post_slug_without_date(post.slug))
  end

  # Gallery page: /2024/01/slug/galeria.html
  def post_gallery_url(year : Int32, month : Int32, slug : String) : String
    "/#{year}/#{"%.2d" % month}/#{slug}/galeria.html"
  end

  def post_gallery_url(post) : String
    post_gallery_url(post.time.year, post.time.month, post_slug_without_date(post.slug))
  end

  # Gallery stats page: /2024/01/slug/galeria-statystyki.html
  def post_gallery_stats_url(year : Int32, month : Int32, slug : String) : String
    "/#{year}/#{"%.2d" % month}/#{slug}/galeria-statystyki.html"
  end

  def post_gallery_stats_url(post) : String
    post_gallery_stats_url(post.time.year, post.time.month, post_slug_without_date(post.slug))
  end

  # Image URL: /images/YYYY/slug/image.jpg
  def post_image_url(year : Int32, slug : String, filename : String, size_prefix : String = "") : String
    base = "/images/#{year}/#{slug}"
    if size_prefix.empty?
      "#{base}/#{filename}"
    else
      "#{base}/#{size_prefix}-#{filename}"
    end
  end

  # Helper: remove date prefix from slug (2024-01-01-slug -> slug)
  private def post_slug_without_date(slug : String) : String
    slug.gsub(/^\d{4}-\d{2}-\d{2}-/, "")
  end

  # ============================================
  # Static Page URLs (Polish)
  # ============================================

  def home_url : String
    "/"
  end

  def map_url : String
    "/mapa_tras.html"
  end

  def about_url : String
    "/o-mnie.html"
  end

  # Baked homepage coverage-map SVG (visited powiaty). NOTE: the file itself
  # is currently generated only by the Go engine (view.CoverageMapSVG);
  # Crystal just links to it from the homepage.
  def coverage_map_svg_url : String
    "/maps/pokrycie_powiatow.svg"
  end

  def year_report_url(year : Int32) : String
    "/rok-#{year}.html"
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
