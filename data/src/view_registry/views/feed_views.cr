# Feed Views
# ==========
#
# These views generate data feeds: RSS, Atom, JSON data files,
# sitemap, and robots.txt.
#
# Current views:
# 1. RSS feed - /feed.xml (priority: 50)
# 2. Atom feed - /feed_atom.xml (priority: 51)
# 3. E2E JSON - /jsons/e2e.json (priority: 52)
# 4. Homepage JSON - /jsons/homepage.json (priority: 52)
# 5. Map JSON - /jsons/map.json (priority: 52)
# 6. Ideas JSON - /jsons/ideas.json (priority: 53)
# 7. Photos JSON - /jsons/photos.json (priority: 54)
# 7b. Photos Map JSON - /jsons/photos_map.json (priority: 54)
# 8. Train stations JSON - /jsons/train_stations.json (priority: 55)
# 9. Photo grid JSON - /jsons/photo_grid.json (priority: 56)
# 10. Sitemap - /sitemap.xml (priority: 58)
# 11. Robots.txt - /robots.txt (priority: 59)
#
# Dependencies: [:posts, :yamls] for most, [:posts] for sitemap/robots
#
# Priority: 50-59 (after stats, before index)
#
# View classes used: SpecialView::RssGenerator, AtomGenerator,
# E2eJsonGenerator, HomePageJsonGenerator, IdeasJsonGenerator,
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
    ctx.render_and_write(SpecialView::RssGenerator.new(
      posts: ctx.posts_newest_first,
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
    ctx.render_and_write(SpecialView::AtomGenerator.new(
      posts: ctx.posts_newest_first,
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

  # E2E JSON - minimal data for E2E tests (not a public endpoint)
  r.register("Feed: e2e JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering e2e JSON" }
    ctx.render_and_write(SpecialView::E2eJsonGenerator.new(context: ctx))
  end

  # Homepage JSON - minimal payload for homepage post collection view
  # Much smaller than payload.json (excludes coords, full area data)
  # URL: /jsons/homepage.json
  r.register("Feed: homepage JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering homepage JSON" }
    ctx.render_and_write(SpecialView::HomePageJsonGenerator.new(context: ctx))
  end

  # Map JSON - optimized payload for /mapa_tras.html
  # Only posts with coords, minimal fields (no area entities)
  # URL: /jsons/map.json
  r.register("Feed: map JSON", [:posts, :yamls], priority: 52) do |ctx|
    ViewRegistry::Log.debug { "Rendering map JSON" }
    ctx.render_and_write(SpecialView::MapJsonGenerator.new(context: ctx))
  end

  # Ideas JSON - data for ideas/planning pages
  r.register("Feed: ideas JSON", [:posts, :yamls], priority: 53) do |ctx|
    ViewRegistry::Log.debug { "Rendering ideas JSON" }
    ctx.render_and_write(SpecialView::IdeasJsonGenerator.new(context: ctx))
  end

  # Photos JSON - photo metadata for galleries
  r.register("Feed: photos JSON", [:posts, :yamls], priority: 54) do |ctx|
    ViewRegistry::Log.debug { "Rendering photos JSON" }
    ctx.render_and_write(SpecialView::PhotosJsonGenerator.new(context: ctx))
  end

  # Photos Map JSON - optimized for /mapa_zdjec.html (photo map)
  # Only photos with lat/lon, excludes detailed EXIF (aperture, exposure, iso, focal)
  # URL: /jsons/photos_map.json
  r.register("Feed: photos map JSON", [:posts, :yamls], priority: 54) do |ctx|
    ViewRegistry::Log.debug { "Rendering photos map JSON" }
    ctx.render_and_write(SpecialView::PhotosMapJsonGenerator.new(context: ctx))
  end

  # Train stations JSON - train station data
  r.register("Feed: train stations JSON", [:posts, :yamls], priority: 55) do |ctx|
    ViewRegistry::Log.debug { "Rendering train stations JSON" }
    ctx.render_and_write(SpecialView::TrainStationsJsonGenerator.new(context: ctx))
  end

  # Photo grid JSON - minimal coords for photo planner
  # URL: /jsons/photo_grid.json
  r.register("Feed: photo grid JSON", [:posts, :yamls], priority: 56) do |ctx|
    ViewRegistry::Log.debug { "Rendering photo grid JSON" }
    ctx.render_and_write(SpecialView::PhotoGridJsonGenerator.new(context: ctx))
  end

  # ============================================
  # Sitemap & Robots
  # ============================================
  #
  # These are SEO-related files.

  # Sitemap - for search engines
  r.register("Feed: sitemap", [:posts], priority: 58) do |ctx|
    ViewRegistry::Log.debug { "Rendering sitemap" }
    ctx.render_and_write(Tremolite::Views::SiteMapGenerator.new(context: ctx))
  end

  # Robots.txt - crawler instructions
  r.register("Feed: robots.txt", [] of Symbol, priority: 59) do |ctx|
    ViewRegistry::Log.debug { "Rendering robots.txt" }
    ctx.render_and_write(Tremolite::Views::RobotGenerator.new)
  end
end
