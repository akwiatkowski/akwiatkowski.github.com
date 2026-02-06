# Feed Views
# ==========
#
# These views generate data feeds: RSS, Atom, JSON data files,
# sitemap, and robots.txt.
#
# Current views:
# 1. RSS feed - /feed.xml (priority: 50)
# 2. Atom feed - /feed_atom.xml (priority: 51)
# 3. Payload JSON - /payload.json (priority: 52)
# 4. Homepage JSON - /jsons/homepage.json (priority: 52) - minimal data for post collection
# 5. Ideas JSON - /ideas.json (priority: 53)
# 6. Photos JSON - /photos.json (priority: 54)
# 7. Train stations JSON - /train_stations.json (priority: 55)
# 8. Nav stats JSON - /nav_stats.json (priority: 56)
# 9. Sitemap - /sitemap.xml (priority: 57)
# 10. Robots.txt - /robots.txt (priority: 58)
#
# Dependencies: [:posts, :yamls] for most, [:posts] for sitemap/robots
#
# Priority: 50-59 (after stats, before index)
#
# View classes used: SpecialView::RssGenerator, AtomGenerator,
# PayloadJsonGenerator, HomePageJsonGenerator, IdeasJsonGenerator,
# PhotosJsonGenerator, TrainStationsJsonGenerator, NavStatsJsonGenerator,
# Tremolite::Views::SiteMapGenerator, RobotGenerator
# (loaded via renderer.cr)

def register_feed_views(r : ViewRegistry)
  # ============================================
  # RSS Feed
  # ============================================
  #
  # Generates RSS 2.0 feed for feed readers.
  #
  # URL: /feed.xml
  # View class: SpecialView::RssGenerator
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Feed: RSS", [:posts, :yamls], priority: 50) do |ctx|
    ViewRegistry::Log.debug { "Rendering RSS feed" }
    ctx.write_output(SpecialView::RssGenerator.new(
      posts: ctx.posts_descending,
      url: "/feed.xml",
      site_title: ctx.site_title,
      site_url: ctx.site_url,
      site_desc: ctx.site_desc,
      site_webmaster: ctx.site_email,
      site_language: "pl",
      updated_at: ctx.last_updated_at
    ))
  end

  # ============================================
  # Atom Feed
  # ============================================
  #
  # Generates Atom feed for feed readers.
  #
  # URL: /feed_atom.xml
  # View class: SpecialView::AtomGenerator
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Feed: Atom", [:posts, :yamls], priority: 51) do |ctx|
    ViewRegistry::Log.debug { "Rendering Atom feed" }
    ctx.write_output(SpecialView::AtomGenerator.new(
      posts: ctx.posts_descending,
      url: "/feed_atom.xml",
      site_title: ctx.site_title,
      site_url: ctx.site_url,
      site_desc: ctx.site_desc,
      site_webmaster: ctx.site_email,
      author_name: ctx.site_author,
      site_language: "pl",
      updated_at: ctx.last_updated_at
    ))
  end

  # ============================================
  # JSON Data Files
  # ============================================
  #
  # These JSON files are consumed by JS frontend pages.

  # Payload JSON - main data payload for JS apps (map, etc.)
  r.register("Feed: payload JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering payload JSON" }
    ctx.write_output(SpecialView::PayloadJsonGenerator.new(context: ctx))
  end

  # Homepage JSON - minimal payload for homepage post collection view
  # Much smaller than payload.json (excludes coords, full area data)
  # URL: /jsons/homepage.json
  r.register("Feed: homepage JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering homepage JSON" }
    ctx.write_output(SpecialView::HomePageJsonGenerator.new(context: ctx))
  end

  # Map JSON - optimized payload for /mapa_tras.html
  # Only posts with coords, minimal fields (no area entities)
  # URL: /jsons/map.json
  r.register("Feed: map JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering map JSON" }
    ctx.write_output(SpecialView::MapJsonGenerator.new(context: ctx))
  end

  # Ideas JSON - data for ideas/planning pages
  r.register("Feed: ideas JSON", [:posts, :yamls], priority: 53) do |ctx|
    ViewRegistry::Log.debug { "Rendering ideas JSON" }
    ctx.write_output(SpecialView::IdeasJsonGenerator.new(context: ctx))
  end

  # Photos JSON - photo metadata for galleries
  r.register("Feed: photos JSON", [:posts, :yamls], priority: 54) do |ctx|
    ViewRegistry::Log.debug { "Rendering photos JSON" }
    ctx.write_output(SpecialView::PhotosJsonGenerator.new(context: ctx))
  end

  # Train stations JSON - train station data
  r.register("Feed: train stations JSON", [:posts, :yamls], priority: 55) do |ctx|
    ViewRegistry::Log.debug { "Rendering train stations JSON" }
    ctx.write_output(SpecialView::TrainStationsJsonGenerator.new(context: ctx))
  end

  # Nav stats JSON - navigation statistics
  r.register("Feed: nav stats JSON", [:posts, :yamls], priority: 56) do |ctx|
    ViewRegistry::Log.debug { "Rendering nav stats JSON" }
    ctx.write_output(SpecialView::NavStatsJsonGenerator.new(context: ctx))
  end

  # ============================================
  # Sitemap & Robots
  # ============================================
  #
  # These are SEO-related files.

  # Sitemap - for search engines
  r.register("Feed: sitemap", [:posts], priority: 57) do |ctx|
    ViewRegistry::Log.debug { "Rendering sitemap" }
    ctx.write_output(Tremolite::Views::SiteMapGenerator.new(context: ctx))
  end

  # Robots.txt - crawler instructions
  r.register("Feed: robots.txt", [] of Symbol, priority: 58) do |ctx|
    ViewRegistry::Log.debug { "Rendering robots.txt" }
    ctx.write_output(Tremolite::Views::RobotGenerator.new)
  end
end
