require "./base_view"

# Home page view with modern design
# URL: / (main home page)
#
# Features:
# - Hero section with featured post (JS fuzzy logic selection)
# - Grid of recent posts (JS mixed strategy selection)
# - Category chips for exploration (JS dynamic rotation)
# - Dark mode support via CSS variables
#
# JS: /js/self/homepage.js fetches /jsons/homepage.json
# and renders dynamic content using vanilla DOM manipulation.
# Hero image is selected randomly from top 4 photos (by points) of the selected post.
#
class HomePageView < BaseView
  Log = ::Log.for(self)

  def initialize(context : RenderContext)
    @url = "/"
    super(context: context, url: @url)
  end

  def title
    context.site_title
  end

  def image_url
    # Use a default image for OG tags (JS will select actual hero)
    best_posts = context.posts.select { |p| p.ready? && p.tag_slugs.includes?("najlepsze") }
    if best_posts.size > 0
      best_posts.first.card_image_url
    else
      context.posts_newest_first.first.card_image_url
    end
  end

  def add_to_sitemap?
    true
  end

  # Additional CSS for new home page
  def page_css : Array(String)
    ["/css/self/new-home.css"]
  end

  # Override to_html for custom layout (no standard nav/footer from base)
  def to_html
    return top_html +
      head_open_html +
      head_title_html +
      head_canonical_html +
      seo_html +
      open_graph_html +
      head_close_html +
      "<body>\n" +
      content +
      "</body>\n" +
      close_html_html
  end

  def content
    data = Hash(String, String).new
    router = context.router

    # Stats (server-rendered, not replaced by JS)
    data["stats.bike_distance"] = total_bike_distance.to_s
    data["stats.hike_distance"] = total_hike_distance.to_s
    data["stats.time_spent"] = total_time_spent.to_s
    data["stats.posts_count"] = format_thousands(total_posts_count)
    data["stats.photos_count"] = format_thousands(total_photos_count)
    data["stats.counties_count"] = format_thousands(counties_with_posts_count)

    # Coverage map section ("Gdzie już byłem")
    data["coverage.map_url"] = router.map_url
    data["coverage.svg_url"] = router.coverage_map_svg_url
    data["coverage.visited"] = format_thousands(counties_with_posts_count)
    data["coverage.total"] = context.areas_of_type(AreaType::County).size.to_s

    # Navigation and footer (shared partials)
    data["navigation"] = load_html("include/navigation/new")
    data["footer"] = load_html("include/footer_new")

    # Hero is now entirely JS-driven (no server-side fallback image)

    # Posts grid - empty placeholder (JS will populate)
    data["posts_grid"] = %(<div class="loading-state">Wczytywanie wpisów...</div>)

    # Category chips - empty placeholder (JS will populate)
    data["categories_chips"] = ""

    load_html("home/new", data)
  end

  # Standalone head (bypasses bundles) — self-hosted fonts + page CSS
  def head_open_html
    String.build do |s|
      s << load_html("include/head_meta")
      # Self-hosted Inter + Playfair Display (no third-party font requests)
      s << %(<link rel="stylesheet" href="/css/self/fonts.css">\n)
      # Page CSS
      s << %(<link rel="stylesheet" href="/css/self/new-home.css">\n)
      s << load_html("include/head_icons")
      s << load_html("include/head_feeds")
      # Homepage JS - vanilla JS with fuzzy logic (no framework needed)
      s << %(<script src="/js/self/homepage.js" defer></script>\n)
    end
  end

  # Stats helpers (server-rendered, not replaced by JS)
  # Note: post.tag_slugs uses English slugs (bicycle, hike), not Polish (rowerem, pieszo)
  private def total_bike_distance : Int32
    context.posts
      .select { |p| p.ready? && p.tag_slugs.includes?("bicycle") }
      .compact_map(&.distance)
      .sum.to_i
  end

  private def total_hike_distance : Int32
    context.posts
      .select { |p| p.ready? && p.tag_slugs.includes?("hike") }
      .compact_map(&.distance)
      .sum.to_i
  end

  private def total_time_spent : Int32
    context.posts
      .select(&.ready?)
      .compact_map(&.time_spent)
      .sum.to_i
  end

  private def total_posts_count : Int32
    context.posts.count(&.ready?)
  end

  private def total_photos_count : Int32
    context.posts
      .select(&.ready?)
      .sum { |p| p.published_photo_entities.size }
  end

  # Counties (powiaty) with at least one post — memoized in RenderContext.
  private def counties_with_posts_count : Int32
    context.areas_with_posts(AreaType::County).size
  end

  # Format an integer with non-breaking spaces as thousands separators
  # (Polish convention), e.g. 15234 → "15 234" — for the hero totals.
  private def format_thousands(number : Int32) : String
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1 ").reverse
  end
end
