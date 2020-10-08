require "./image_resizer"
require "./data_manager"
require "./post"
require "./renderer"
require "./post_function_parser"
require "./validator"
require "./mod_watcher"
require "./services/town_photo_cache"

class Tremolite::Blog
  def mod_watcher_summary
    # keep in mind posts were not yet loaded
    # 0) check what was changed
    mod_watcher.load_from_file
    changes_summary = mod_watcher.changed_summary

    # only these posts will be updated
    # load md, process md -> html, while converting create PhotoEntity
    # exif data is needed (photo link to map, photo data attribs)
    # so we still need to update exif which require loading db
    # because of that I'll split exif and photo data to separate files
    post_paths_to_update = changes_summary[Tremolite::ModWatcher::KEY_POSTS_FILES]
    Log.debug { "#{post_paths_to_update.size} posts changed" }

    post_to_render = post_collection.posts.select do |post|
      post_paths_to_update.includes?(post.path)
    end

    # if yaml config was changed we need to re-render all posts and
    if changes_summary[Tremolite::ModWatcher::KEY_YAML_FILES].size > 0
      Log.debug { "YAML changed -> rendering all posts + YAML views" }
      yamls_changed = true
    else
      yamls_changed = false
    end

    if post_paths_to_update.size > 0
      posts_changed = true
    else
      posts_changed = false
    end

    post_slugs_to_update_photos = changes_summary[Tremolite::ModWatcher::KEY_PHOTO_FILES].map do |photo_path|
      scan = photo_path.scan(/(\d{4}-\d{2}-\d{2}[^\/]+)/)
      next if scan.size == 0 || scan[0].size == 0
      # first (0) mached and first (1) group
      scan[0][1].to_s
    end.uniq

    post_to_update_photos = post_collection.posts.select do |post|
      post_slugs_to_update_photos.includes?(post.slug)
    end
    Log.debug { "Update #{post_to_update_photos.size} post photos" }

    post_slugs_to_update_exif = changes_summary[Tremolite::ModWatcher::KEY_EXIF_DB_FILES].map do |exif_path|
      scan = exif_path.scan(/(\d{4}-\d{2}-\d{2}[^\.]+).yml/)
      # first (0) mached and first (1) group
      scan[0][1].to_s
    end.uniq

    post_to_update_exif = post_collection.posts.select do |post|
      post_slugs_to_update_exif.includes?(post.slug)
    end
    Log.debug { "Update #{post_to_update_photos.size} post exif" }

    if post_to_update_exif.size > 0
      exifs_changed = true
    else
      exifs_changed = false
    end

    return {
      post_to_render:        post_to_render,
      posts_changed:         posts_changed,
      yamls_changed:         yamls_changed,
      post_to_update_photos: post_to_update_photos,
      post_to_update_exif:   post_to_update_exif,
      exifs_changed:         exifs_changed,
    }
  end

  def make_it_so(
    force_full_render : Bool = false,
    exifs_changed : Bool = false
  )
    # ** new way is to render what has changed

    # first we need to initialize all posts
    # ...unfortunately
    Log.debug { "PostCollection#initialize_posts" }
    post_collection.initialize_posts
    Log.debug { "PostCollection#initialize_posts DONE" }

    if mod_watcher.enabled == false || force_full_render
      all_posts = post_collection.posts
      post_to_render = all_posts
      posts_changed = true
      yamls_changed = true
      post_to_update_photos = all_posts
      post_to_update_exif = all_posts
      exifs_changed = true
    else
      tuple = mod_watcher_summary
      post_to_render = tuple[:post_to_render]
      posts_changed = tuple[:posts_changed]
      yamls_changed = tuple[:yamls_changed]
      post_to_update_photos = tuple[:post_to_update_photos]
      post_to_update_exif = tuple[:post_to_update_exif]
      exifs_changed ||= tuple[:exifs_changed]
    end

    render(
      post_to_render: post_to_render,
      posts_changed: posts_changed,
      yamls_changed: yamls_changed,
      post_to_update_photos: post_to_update_photos,
      post_to_update_exif: post_to_update_exif,
      exifs_changed: exifs_changed,
    )

    validator.run

    # Z) store current state
    # current state is refreshed in `#update_before_save`
    mod_watcher.save_to_file
  end

  def render(
    post_to_render : Array(Tremolite::Post),
    posts_changed : Bool,
    yamls_changed : Bool,
    post_to_update_photos : Array(Tremolite::Post),
    post_to_update_exif : Array(Tremolite::Post),
    exifs_changed : Bool
  )
    # test+dev stuff
    renderer.dev_render

    # because
    post_to_render_galleries = (post_to_update_photos + post_to_update_exif).uniq
    post_to_render_only_post = post_to_render - post_to_render_galleries

    # uses rsync so it's fast
    renderer.render_copy_assets

    post_to_render_galleries.each do |post|
      Log.debug { "resize_all_images_for_post" }
      @image_resizer.not_nil!.resize_all_images_for_post(
        post: post,
        overwrite: false
      )
      Log.debug { "#{post.slug} - preparing content" }
      data_manager.exif_db.initialize_post_photos_exif(post)
      Log.debug { "#{post.slug} - rendering" }
      renderer.render_post(post)
      Log.debug { "#{post.slug} - rendering galleries" }
      renderer.render_post_galleries_for_post(post)
      Log.debug { "#{post.slug} - saving exif cache" }
      data_manager.exif_db.save_cache(post.slug)
      Log.debug { "#{post.slug} - DONE" }
    end

    post_to_render_only_post.each do |post|
      Log.debug { "resize_all_images_for_post" }
      @image_resizer.not_nil!.resize_all_images_for_post(
        post: post,
        overwrite: false
      )
      Log.debug { "#{post.slug} - preparing content" }
      post.content_html
      Log.debug { "#{post.slug} - rendering" }
      renderer.render_post(post)
      Log.debug { "#{post.slug} - saving exif cache" }
      data_manager.exif_db.save_cache(post.slug)
      Log.debug { "#{post.slug} - DONE" }
    end

    # TODO move somewhere else
    renderer.render_portfolio

    if exifs_changed
      # first we need to load all (and/or process new) exif data
      post_collection.posts.each do |post|
        data_manager.exif_db.initialize_post_photos_exif(post)
      end
      # recalculate towns photo for closest photo
      data_manager.town_photo_cache.not_nil!.refresh

      renderer.render_exif_page
      # this probably should be updated more often
      # but at leas is not overwritten
      renderer.render_galleries_pages
    end

    # moved after town cache update to have refreshed town images

    # if post were changed render some fast related pages
    if posts_changed
      renderer.render_fast_only_post_related
    end

    if posts_changed || yamls_changed
      renderer.render_fast_post_and_yaml_related
    end

    # maybe somewhere in future we can add if here
    renderer.render_fast_static_renders
  end

  def routes_path
    @routes_path ||= File.join(
      [
        @data_path.as(String),
        "routes",
      ]
    )
  end
end
