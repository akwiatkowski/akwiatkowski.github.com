# Feed Views
# ==========
#
# These views generate data feeds: RSS, Atom, JSON data files,
# sitemap, and robots.txt.
#
# Current views:
# 1. RSS feed - /feed.xml (priority: 50)
# 2. Atom feed - /feed_atom.xml (priority: 51)
# 3. Payload JSON - /data/payload.json (priority: 52)
# 4. Ideas JSON - /data/ideas.json (priority: 53)
# 5. Photos JSON - /data/photos.json (priority: 54)
# 6. Train stations JSON - /data/train_stations.json (priority: 55)
# 7. Nav stats JSON - /data/nav_stats.json (priority: 56)
# 8. Sitemap - /sitemap.xml (priority: 57)
# 9. Robots.txt - /robots.txt (priority: 58)
#
# Dependencies: [:posts, :yamls] for most, [:posts] for sitemap/robots
#
# Priority: 50-59 (after stats, before index)
#
# Source: Extracted from render_special.cr
#
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
  # Original code (render_special.cr:50-63)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Feed: RSS", [:posts, :yamls], priority: 50) do |ctx|
    ViewRegistry::Log.debug { "Rendering RSS feed" }
    ctx.blog.renderer.render_rss
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
  # Original code (render_special.cr:66-82)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Feed: Atom", [:posts, :yamls], priority: 51) do |ctx|
    ViewRegistry::Log.debug { "Rendering Atom feed" }
    ctx.blog.renderer.render_atom
  end

  # ============================================
  # JSON Data Files
  # ============================================
  #
  # These JSON files are consumed by JS frontend pages.

  # Payload JSON - main data payload for JS apps
  r.register("Feed: payload JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering payload JSON" }
    ctx.blog.renderer.render_payload_json
  end

  # Ideas JSON - data for ideas/planning pages
  r.register("Feed: ideas JSON", [:posts, :yamls], priority: 53) do |ctx|
    ViewRegistry::Log.debug { "Rendering ideas JSON" }
    ctx.blog.renderer.render_ideas_json
  end

  # Photos JSON - photo metadata for galleries
  r.register("Feed: photos JSON", [:posts, :yamls], priority: 54) do |ctx|
    ViewRegistry::Log.debug { "Rendering photos JSON" }
    ctx.blog.renderer.render_photos_json
  end

  # Train stations JSON - train station data
  r.register("Feed: train stations JSON", [:posts, :yamls], priority: 55) do |ctx|
    ViewRegistry::Log.debug { "Rendering train stations JSON" }
    ctx.blog.renderer.render_train_stations_json
  end

  # Nav stats JSON - navigation statistics
  r.register("Feed: nav stats JSON", [:posts, :yamls], priority: 56) do |ctx|
    ViewRegistry::Log.debug { "Rendering nav stats JSON" }
    ctx.blog.renderer.render_nav_stats_json
  end

  # ============================================
  # Sitemap & Robots
  # ============================================
  #
  # These are SEO-related files.

  # Sitemap - for search engines
  # Note: In blog.cr this only runs on full render, but
  # we'll let the coordinator decide based on dependencies
  r.register("Feed: sitemap", [:posts], priority: 57) do |ctx|
    ViewRegistry::Log.debug { "Rendering sitemap" }
    ctx.blog.renderer.render_sitemap
  end

  # Robots.txt - crawler instructions
  r.register("Feed: robots.txt", [] of Symbol, priority: 58) do |ctx|
    ViewRegistry::Log.debug { "Rendering robots.txt" }
    ctx.blog.renderer.render_robot
  end
end
