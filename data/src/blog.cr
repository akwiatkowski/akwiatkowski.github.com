require "./image_resizer"
require "./data_manager"
require "./post"
require "./renderer"
require "./post_function_parser"
require "./post_collection"
require "./validator"
require "./mod_watcher"
# PHASE6_REMOVED: require "./services/town_photo_cache" - replaced by AreaPhotoSelector
require "./services/post_coord_quant_cache"
require "./services/external_gpx_preprocessor"
require "./services/tools/all"
require "./services/output_history"
require "./services/asset_bundle_loader"
require "./services/html_processor"
require "./services/router"
require "./services/route_colors"
require "./render_context"
require "./post_renderer"
require "./view_registry/all"

class Tremolite::Blog
  # ============================================
  # View Registry Integration
  # ============================================
  #
  # The ViewRegistry provides a declarative way to manage what renders when.
  # Use render_with_registry for the new coordinated render path.
  #

  @view_registry : ViewRegistry?
  @render_coordinator : RenderCoordinator?
  @output_history : OutputHistory?

  # Lazy-initialized registry with all views/tasks registered
  def view_registry : ViewRegistry
    @view_registry ||= setup_view_registry
  end

  # Coordinator that executes views based on what changed
  def render_coordinator : RenderCoordinator
    @render_coordinator ||= RenderCoordinator.new(view_registry)
  end

  def context
    @context ||= RenderContext.new(self)
  end

  # Output history for tracking file changes
  # Env and target are extracted from output_path (e.g., "env/dev/public/local" -> env="dev", target="local")
  def output_history : OutputHistory
    @output_history ||= begin
      parts = output_path.split('/')
      env = parts[1]? || "dev"       # env/dev/public/local -> "dev"
      target = File.basename(output_path)
      history = OutputHistory.new(env: env, target: target)
      html_buffer.output_history = history
      history
    end
  end

  # New render method using the registry
  # This can run alongside the old render method for validation
  def render_with_registry(
    posts_changed : Bool,
    yamls_changed : Bool,
    exifs_changed : Bool,
  )
    # Build the changed set
    changed = Set(Symbol).new
    changed << :posts if posts_changed
    changed << :yamls if yamls_changed
    changed << :exifs if exifs_changed

    # If nothing changed, run "always run" entries only
    if changed.empty?
      Log.info { "render_with_registry: no changes, running always-run entries only" }
    end

    render_coordinator.render(context, changed)
  end

  # Full render using registry (convenience method)
  def render_all_with_registry
    render_with_registry(
      posts_changed: true,
      yamls_changed: true,
      exifs_changed: true
    )
  end

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
      Log.info { "YAML changed -> rendering all posts + YAML views" }
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
    exifs_changed : Bool = false,
    # when post is not finished it's content won't be rendered
    # this lead to empty posts on release server
    hide_not_finished : Bool = false,
  )
    # ** new way is to render what has changed

    # first we need to initialize all posts
    # ...unfortunately
    Log.info { "PostCollection#initialize_posts" }
    post_collection.initialize_posts
    Log.info { "PostCollection#initialize_posts DONE" }

    # Set area_data_loader on all posts for area associations
    area_loader = data_manager.not_nil!.area_data_loader.not_nil!
    post_collection.posts.each { |post| post.area_data_loader = area_loader }
    Log.info { "Set area_data_loader on #{post_collection.posts.size} posts" }

    populate_referenced_links
    Log.info { "Populated HtmlBuffer referenced links" }

    if mod_watcher.enabled == false || force_full_render
      all_posts = post_collection.posts
      post_to_render = all_posts
      posts_changed = true
      yamls_changed = true
      post_to_update_photos = all_posts
      post_to_update_exif = all_posts
      exifs_changed = true
      refresh_nav_stats = true
    else
      tuple = mod_watcher_summary
      post_to_render = tuple[:post_to_render]
      posts_changed = tuple[:posts_changed]
      yamls_changed = tuple[:yamls_changed]
      post_to_update_photos = tuple[:post_to_update_photos]
      post_to_update_exif = tuple[:post_to_update_exif]
      exifs_changed ||= tuple[:exifs_changed]
      # XXX for now do not update nav stats when using mod-watcher
      # XXX this should be false but can be set as true while dev
      refresh_nav_stats = false
    end

    render(
      post_to_render: post_to_render,
      posts_changed: posts_changed,
      yamls_changed: yamls_changed,
      post_to_update_photos: post_to_update_photos,
      post_to_update_exif: post_to_update_exif,
      exifs_changed: exifs_changed,
      refresh_nav_stats: refresh_nav_stats,
      hide_not_finished: hide_not_finished
    )

    # update sitemap only when full render to not mess
    # with google stuff
    if force_full_render
      ctx = RenderContext.new(self)
      ctx.write_output(Tremolite::Views::SiteMapGenerator.new(context: context))
    end

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
    exifs_changed : Bool,
    refresh_nav_stats : Bool,
    hide_not_finished : Bool,
  )
    # ============================================
    # Initialize output history tracking
    # ============================================
    # Must be done before any rendering so all changes are tracked.
    output_history

    # ============================================
    # Per-post rendering
    # ============================================
    # These operations depend on which specific posts changed.
    # Posts with photo/EXIF changes need full gallery rendering.
    # Posts with only content changes need just article rendering.

    post_to_render_galleries = (post_to_update_photos + post_to_update_exif).uniq
    post_to_render_only_post = post_to_render - post_to_render_galleries

    post_renderer = PostRenderer.new(self)
    post_renderer.render_with_galleries(post_to_render_galleries, hide_not_finished)
    post_renderer.render_content_only(post_to_render_only_post, hide_not_finished)

    # ============================================
    # Registry-based rendering
    # ============================================
    # All aggregate views (entity pages, galleries, feeds, etc.)
    # are handled by the ViewRegistry.

    render_with_registry(
      posts_changed: posts_changed,
      yamls_changed: yamls_changed,
      exifs_changed: exifs_changed
    )

    # ============================================
    # Generate history index and summary
    # ============================================
    output_history.generate_index_html
    output_history.print_summary
  end

  # TODO check if it's used
  def routes_path
    @routes_path ||= File.join(
      [
        @data_path.as(String),
        "routes",
      ]
    )
  end

  private def populate_referenced_links
    # TODO think about `not_nil!`
    # convert getters into custom methods
    @data_manager.not_nil!.preloaded_post_referenced_links.populate_referenced_links
  end
end
