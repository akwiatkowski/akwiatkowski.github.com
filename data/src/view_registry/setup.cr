# Setup the complete ViewRegistry with all tasks and views.
#
# This is the SINGLE SOURCE OF TRUTH for what renders when.
# All tasks and views are registered here with their dependencies.
#
# ============================================
# Priority Guide
# ============================================
#
# Tasks (run before views, prepare data):
#   1-2:    Setup tasks (dev render, copy assets)
#   3-4:    EXIF tasks (initialize EXIF data)
#   5-9:    Cache tasks (nav stats, town photos, coord quant)
#
# Views (render output):
#   10-19:  Entity views (towns, tags, voivodeships, lands)
#   20-29:  Home/list views (home, new posts, paginated)
#   30-39:  Photo views (galleries, maps)
#   40-49:  Stats views (summary, year reports)
#   50-59:  Feed views (RSS, Atom, JSON)
#   60-69:  Index views (towns index, lands index)
#   90-99:  Static views (about, more)
#   100:    Debug views
#
# ============================================
# Dependency Types
# ============================================
#
# :posts  - Post content changed (markdown files)
# :yamls  - YAML config changed (entities, settings)
# :exifs  - EXIF data changed (photo metadata)
#
# Empty array [] means "always run"
#
def setup_view_registry : ViewRegistry
  r = ViewRegistry.new

  # ==========================================
  # Tasks (data preparation, priority 1-9)
  # ==========================================

  # Priority 1-2: Setup (always runs)
  register_setup_tasks(r)

  # Priority 3-4: EXIF initialization (when exifs changed)
  register_exif_tasks(r)

  # Priority 5-9: Cache refresh (various dependencies)
  register_cache_tasks(r)

  # ==========================================
  # Views (render output, priority 10-100)
  # ==========================================

  # Priority 10-19: Entity views (towns, tags, voivodeships, lands)
  register_entity_views(r)

  # Priority 14-16: Area views (unified area system - show, post list, gallery)
  register_area_views(r)

  # Priority 20-29: Home/list views (home, map, pois)
  register_home_views(r)

  # Priority 30-39: Photo views (galleries, maps)
  register_photo_views(r)

  # Priority 40-49: Stats views (summary, year reports, burnout)
  register_stats_views(r)

  # Priority 50-59: Feed views (RSS, Atom, JSON, sitemap)
  register_feed_views(r)

  # Priority 60-69: Index views (towns index, lands index)
  register_index_views(r)

  # Priority 90-99: Static views (about, more, JS pages)
  register_static_views(r)

  # Priority 100+: Debug views
  register_debug_views(r)

  r
end
