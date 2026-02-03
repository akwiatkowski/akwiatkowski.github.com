# EXIF Tasks
# ==========
#
# These tasks handle EXIF data initialization for photos.
# EXIF data includes camera info, lens, GPS coordinates, etc.
#
# Current tasks:
# 1. Initialize EXIF data for all posts (priority: 4)
#
# Priority: 4 (after setup, before cache refresh that depends on EXIF)
#
# Source: Extracted from Blog#render in data/src/blog.cr:220-222
#
# Note: The cache tasks (town_photo_cache, post_coord_quant_cache)
# depend on EXIF data being loaded first. That's why EXIF init
# has priority 4, and cache tasks have priority 5-6.
#
def register_exif_tasks(r : ViewRegistry)
  # ============================================
  # Task: Initialize EXIF Data for All Posts
  # ============================================
  #
  # Loads and processes EXIF data for all photos in all posts.
  # This populates the exif_db with photo metadata that views
  # need for rendering galleries, maps, and photo details.
  #
  # Original code (blog.cr:220-222):
  #   post_collection.posts.each do |post|
  #     data_manager.exif_db.initialize_post_photos_exif(post)
  #   end
  #
  # This is the BULK initialization that runs when exifs_changed.
  # Individual post EXIF is also initialized during post rendering
  # (blog.cr:185), but this task ensures ALL posts have EXIF
  # loaded before photo-related views render.
  #
  # Dependencies: [:exifs] - only when EXIF data changed
  # Priority: 4 (before cache tasks that need EXIF data)
  #
  r.task("EXIF: init all posts", [:exifs], priority: 4) do |ctx|
    posts = ctx.posts
    exif_db = ctx.exif_db

    ViewRegistry::Log.info { "Initializing EXIF data for #{posts.size} posts" }

    posts.each_with_index do |post, idx|
      # Log progress every 20 posts to avoid log spam
      if idx > 0 && idx % 20 == 0
        ViewRegistry::Log.debug { "EXIF init progress: #{idx}/#{posts.size}" }
      end

      exif_db.initialize_post_photos_exif(post)
    end

    ViewRegistry::Log.info { "EXIF initialization complete" }
  end
end
