# View Registry - All Components
# ==============================
#
# This file requires all view_registry components in the correct order.
# Import this single file to get the complete registry system.
#
# Usage:
#   require "./view_registry/all"
#
#   registry = setup_view_registry
#   coordinator = RenderCoordinator.new(registry)
#   coordinator.render(context, changed: Set{:posts})
#

# Core classes
require "./base"
require "./coordinator"

# Tasks (data preparation)
# Order doesn't matter here - priority controls execution order
require "./tasks/setup_tasks"
require "./tasks/exif_tasks"
require "./tasks/cache_tasks"

# Views (render output)
require "./views/entity_views"
require "./views/home_views"
require "./views/photo_views"
require "./views/stats_views"
require "./views/feed_views"
require "./views/index_views"
require "./views/static_views"
require "./views/debug_views"

# Setup function that combines everything
require "./setup"
