require "./base_view"

# New "more" page with modern design matching homepage
# URL: /wiecej.html
#
# Features:
# - Same styling as new homepage (new-home.css)
# - Collection of misc links for easy expansion
# - Dark mode support via CSS variables
#
class NewMoreView < BaseView
  Log = ::Log.for(self)

  def initialize(context : RenderContext)
    @url = "/wiecej.html"
    super(context: context, url: @url)
  end

  def title
    "Więcej - #{context.site_title}"
  end

  def image_url
    context.posts_from_latest.first.card_image_url
  end

  def add_to_sitemap?
    true
  end

  # Additional CSS for new more page (same as homepage)
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

    # Navigation and footer (shared partials)
    data["navigation"] = load_html("include/navigation/new")
    data["footer"] = load_html("include/footer_new")

    # Links section - add more links here as needed
    data["links_content"] = build_links_html

    load_html("more/new", data)
  end

  # Include Google Fonts for the new design
  def head_open_html
    String.build do |s|
      s << load_html("include/head_meta")
      # Google Fonts
      s << %(<link rel="preconnect" href="https://fonts.googleapis.com">\n)
      s << %(<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n)
      s << %(<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&family=Playfair+Display:wght@400;500;600&display=swap" rel="stylesheet">\n)
      # Page CSS
      s << %(<link rel="stylesheet" href="/css/self/new-home.css">\n)
      s << load_html("include/head_icons")
      s << load_html("include/head_feeds")
    end
  end

  # Build links HTML - easy to add new links
  # Each link is rendered as a card with icon, name and description
  private def build_links_html : String
    links = [
      {name: "Mapa zdjęć", url: "/mapa2.html", icon: "photos", desc: "Przeglądaj zdjęcia na mapie w stylu Panoramio"},
    ]

    String.build do |s|
      links.each do |link|
        s << %(<a href="#{link[:url]}" class="more-link">\n)
        s << %(  <div class="more-link-icon">#{get_icon_svg(link[:icon])}</div>\n)
        s << %(  <div class="more-link-text">\n)
        s << %(    <span class="more-link-name">#{link[:name]}</span>\n)
        s << %(    <span class="more-link-desc">#{link[:desc]}</span>\n)
        s << %(  </div>\n)
        s << %(</a>\n)
      end
    end
  end

  private def get_icon_svg(name : String) : String
    icons = {
      "map" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l5.447 2.724A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/></svg>),
      "camera" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/><circle cx="12" cy="13" r="3"/></svg>),
      "photos" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>),
      "stats" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>),
      "user" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>),
      "rss" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M6 5c7.18 0 13 5.82 13 13M6 11a7 7 0 017 7m-6 0a1 1 0 11-2 0 1 1 0 012 0z"/></svg>),
      "clock" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>),
      "idea" => %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/></svg>),
    }
    icons[name]? || ""
  end
end
