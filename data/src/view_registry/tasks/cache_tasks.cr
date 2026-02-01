# Cache Tasks
# ===========
#
# These tasks refresh various caches that views depend on.
# They run after setup tasks but before any views.
#
# Current tasks:
# 1. Nav stats cache - navigation statistics (priority: 5)
# 2. Town photo cache - closest photo for each town (priority: 6)
# 3. Coord quant cache - post coordinate quantization (priority: 6)
#
# Priority: 5-6 (after setup, before views)
#
# Source: Extracted from Blog#render in data/src/blog.cr:173-229
#
def register_cache_tasks(r : ViewRegistry)
  # ============================================
  # Task: Refresh Nav Stats Cache
  # ============================================
  #
  # Refreshes navigation statistics cache used for showing
  # post counts next to navigation items (towns, tags, etc).
  #
  # Original code (blog.cr:173-175):
  #   if refresh_nav_stats
  #     data_manager.nav_stats_cache.not_nil!.refresh
  #   end
  #
  # Note: In current blog.cr, this only runs on full render
  # (refresh_nav_stats=true). For registry, we tie it to
  # :yamls dependency since yamls define the entities.
  #
  # Dependencies: [:yamls] - entity definitions may have changed
  # Priority: 5
  #
  # TODO: Consider adding a :full_render dependency type
  # for tasks that only run on full renders.
  #
  r.task("Cache: nav stats", [:yamls], priority: 5) do |ctx|
    ViewRegistry::Log.info { "Refreshing nav_stats_cache" }

    cache = ctx.blog.data_manager.not_nil!.nav_stats_cache
    if cache
      cache.refresh
      ViewRegistry::Log.debug { "nav_stats_cache refreshed" }
    else
      ViewRegistry::Log.warn { "nav_stats_cache is nil, skipping" }
    end
  end

  # ============================================
  # Task: Refresh Town Photo Cache
  # ============================================
  #
  # Recalculates the closest/best photo for each town.
  # This is used for town thumbnails in listings.
  #
  # Original code (blog.cr:225):
  #   data_manager.town_photo_cache.not_nil!.refresh
  #
  # This runs when exifs_changed because photo coordinates
  # come from EXIF data.
  #
  # Dependencies: [:exifs] - photo locations may have changed
  # Priority: 6 (after nav stats, needs EXIF data loaded first)
  #
  r.task("Cache: town photos", [:exifs], priority: 6) do |ctx|
    ViewRegistry::Log.info { "Refreshing town_photo_cache" }

    cache = ctx.blog.data_manager.not_nil!.town_photo_cache
    if cache
      cache.refresh
      ViewRegistry::Log.debug { "town_photo_cache refreshed" }
    else
      ViewRegistry::Log.warn { "town_photo_cache is nil, skipping" }
    end
  end

  # ============================================
  # Task: Refresh Post Coord Quant Cache
  # ============================================
  #
  # Recalculates coordinate quantization for posts.
  # This is used for the "similar posts by location" feature
  # and for generating location-based maps.
  #
  # Original code (blog.cr:229):
  #   data_manager.post_coord_quant_cache.not_nil!.refresh
  #
  # This runs when exifs_changed because coordinates come
  # from EXIF data.
  #
  # Dependencies: [:exifs] - photo locations may have changed
  # Priority: 6 (parallel with town photo cache)
  #
  r.task("Cache: coord quant", [:exifs], priority: 6) do |ctx|
    ViewRegistry::Log.info { "Refreshing post_coord_quant_cache" }

    cache = ctx.blog.data_manager.not_nil!.post_coord_quant_cache
    if cache
      cache.refresh
      ViewRegistry::Log.debug { "post_coord_quant_cache refreshed" }
    else
      ViewRegistry::Log.warn { "post_coord_quant_cache is nil, skipping" }
    end
  end
end
