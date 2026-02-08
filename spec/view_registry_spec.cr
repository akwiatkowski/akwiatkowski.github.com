# View Registry Spec
# ==================
#
# Tests for the ViewRegistry and RenderCoordinator.
# Verifies that tasks are registered correctly and
# the coordinator can query/execute them.
#
require "./spec_helper"
require "../data/src/view_registry/all"

describe ViewRegistry do
  describe "#task" do
    it "registers a task with is_task=true" do
      r = ViewRegistry.new
      r.task("Test task", [:posts], priority: 1) { |ctx| }

      r.entries.size.should eq(1)
      r.entries[0].is_task.should be_true
      r.entries[0].name.should eq("Test task")
      r.entries[0].depends_on.should eq([:posts])
      r.entries[0].priority.should eq(1)
    end
  end

  describe "#register" do
    it "registers a view with is_task=false" do
      r = ViewRegistry.new
      r.register("Test view", [:posts, :yamls], priority: 10) { |ctx| }

      r.entries.size.should eq(1)
      r.entries[0].is_task.should be_false
      r.entries[0].name.should eq("Test view")
      r.entries[0].depends_on.should eq([:posts, :yamls])
      r.entries[0].priority.should eq(10)
    end
  end

  describe "#entries_for" do
    it "returns entries matching the given dependencies" do
      r = ViewRegistry.new
      r.task("Posts only", [:posts]) { |ctx| }
      r.task("Exifs only", [:exifs]) { |ctx| }
      r.task("Posts and yamls", [:posts, :yamls]) { |ctx| }

      posts_entries = r.entries_for(:posts)
      posts_entries.size.should eq(2)
      posts_entries.map(&.name).should contain("Posts only")
      posts_entries.map(&.name).should contain("Posts and yamls")

      exifs_entries = r.entries_for(:exifs)
      exifs_entries.size.should eq(1)
      exifs_entries[0].name.should eq("Exifs only")
    end

    it "returns entries with empty depends_on (always run)" do
      r = ViewRegistry.new
      r.task("Always run", [] of Symbol) { |ctx| }
      r.task("Posts only", [:posts]) { |ctx| }

      # Empty depends_on should match any query
      entries = r.entries_for(:posts)
      entries.size.should eq(2)
    end

    it "sorts by priority" do
      r = ViewRegistry.new
      r.task("High priority", [:posts], priority: 100) { |ctx| }
      r.task("Low priority", [:posts], priority: 1) { |ctx| }
      r.task("Medium priority", [:posts], priority: 50) { |ctx| }

      entries = r.entries_for(:posts)
      entries[0].name.should eq("Low priority")
      entries[1].name.should eq("Medium priority")
      entries[2].name.should eq("High priority")
    end
  end

  describe "#names_depending_on" do
    it "returns just the names" do
      r = ViewRegistry.new
      r.task("Task A", [:posts]) { |ctx| }
      r.task("Task B", [:posts, :exifs]) { |ctx| }
      r.task("Task C", [:exifs]) { |ctx| }

      r.names_depending_on(:posts).should eq(["Task A", "Task B"])
      r.names_depending_on(:exifs).should eq(["Task B", "Task C"])
    end
  end

  describe "#tasks and #views" do
    it "filters by is_task flag" do
      r = ViewRegistry.new
      r.task("Task 1", [:posts]) { |ctx| }
      r.task("Task 2", [:exifs]) { |ctx| }
      r.register("View 1", [:posts]) { |ctx| }

      r.tasks.size.should eq(2)
      r.views.size.should eq(1)
    end
  end
end

describe "setup_view_registry" do
  # ============================================
  # Task Registration Tests
  # ============================================

  describe "tasks" do
    it "registers all expected tasks" do
      r = setup_view_registry

      # Should have 6 tasks total
      r.tasks.size.should eq(6)

      # Check all tasks exist
      task_names = r.tasks.map(&.name)
      task_names.should contain("Setup: dev render")
      task_names.should contain("Setup: copy assets")
      task_names.should contain("EXIF: init all posts")
      task_names.should contain("Cache: nav stats")
      # PHASE6_DEPRECATED: task_names.should contain("Cache: town photos") - replaced by AreaPhotoSelector
      task_names.should contain("Cache: coord quant")
    end

    it "has correct setup task configuration" do
      r = setup_view_registry

      dev_render = r.tasks.find { |t| t.name == "Setup: dev render" }.not_nil!
      dev_render.depends_on.should eq([] of Symbol)
      dev_render.priority.should eq(1)
      dev_render.is_task.should be_true

      copy_assets = r.tasks.find { |t| t.name == "Setup: copy assets" }.not_nil!
      copy_assets.depends_on.should eq([] of Symbol)
      copy_assets.priority.should eq(2)
      copy_assets.is_task.should be_true
    end

    it "has correct EXIF task configuration" do
      r = setup_view_registry

      exif_task = r.tasks.find { |t| t.name == "EXIF: init all posts" }.not_nil!
      exif_task.depends_on.should eq([:exifs])
      exif_task.priority.should eq(4)
      exif_task.is_task.should be_true
    end

    it "has correct cache task configuration" do
      r = setup_view_registry

      nav_stats = r.tasks.find { |t| t.name == "Cache: nav stats" }.not_nil!
      nav_stats.depends_on.should eq([:yamls])
      nav_stats.priority.should eq(5)

      # PHASE6_DEPRECATED: town_photos cache task - replaced by AreaPhotoSelector
      # town_photos = r.tasks.find { |t| t.name == "Cache: town photos" }.not_nil!
      # town_photos.depends_on.should eq([:exifs])
      # town_photos.priority.should eq(6)

      coord_quant = r.tasks.find { |t| t.name == "Cache: coord quant" }.not_nil!
      coord_quant.depends_on.should eq([:exifs])
      coord_quant.priority.should eq(6)
    end
  end

  # ============================================
  # View Registration Tests
  # ============================================

  describe "views" do
    it "registers all expected views" do
      r = setup_view_registry

      # Should have 40 views total:
      # - Entity views: 2 (tags, tags legacy redirects)
      # - Area views: 4 (show pages, post list pages, gallery pages, external areas post list)
      # - Home views: 4 (main, old home, map, pois)
      # - Photo views: 2 (galleries, maps)
      # - Stats views: 4 (year reports, burnout, towns history, towns timeline)
      # - Feed views: 12 (RSS, Atom, 8x JSON, sitemap, robots)
      # - Index views: 1 (towns only - lands deprecated)
      # - Static views: 8 (more, about, english, trip ideas, JS timeline, photo map, JS exif stats, photo planner)
      # - Debug views: 3 (posts, camera stuff, missing EXIF)
      r.views.size.should eq(40)
    end

    it "registers all entity views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      # PHASE6_DEPRECATED: Towns, Voivodeships, Lands migrated to AreaEntity system
      # view_names.should contain("Towns: all pages")
      view_names.should contain("Tags: all pages")
      # view_names.should contain("Voivodeships: all pages")
      # view_names.should contain("Lands: all pages")
    end

    it "registers all home views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Home: main page")
      view_names.should contain("Home: old home page")
      view_names.should contain("Home: route map page")
      view_names.should contain("Home: POIs page")
    end

    it "registers all photo views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Photo galleries: all")
      view_names.should contain("Photo maps: all")
    end

    it "registers all stats views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Stats: year reports")
      view_names.should contain("Stats: burnout")
      view_names.should contain("Stats: towns history")
      view_names.should contain("Stats: towns timeline")
    end

    it "registers all index views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Index: towns")
      # PHASE6_DEPRECATED: view_names.should contain("Index: lands") - uses LandEntity
    end

    it "registers all static views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Static: new more page")
      view_names.should contain("Static: about page")
      view_names.should contain("Static: english page")
      view_names.should contain("Static: trip ideas")
      view_names.should contain("Static: JS timeline")
      view_names.should contain("Static: photo map")
      view_names.should contain("Static: JS exif stats")
      view_names.should contain("Static: photo planner")
    end

    it "registers all feed views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Feed: RSS")
      view_names.should contain("Feed: Atom")
      view_names.should contain("Feed: payload JSON")
      view_names.should contain("Feed: ideas JSON")
      view_names.should contain("Feed: photos JSON")
      view_names.should contain("Feed: photo grid JSON")
      view_names.should contain("Feed: train stations JSON")
      view_names.should contain("Feed: sitemap")
      view_names.should contain("Feed: robots.txt")
    end

    it "registers all debug views" do
      r = setup_view_registry
      view_names = r.views.map(&.name)

      view_names.should contain("Debug: posts")
      view_names.should contain("Debug: camera stuff")
      view_names.should contain("Debug: missing EXIF")
    end
  end

  # ============================================
  # Priority Tests
  # ============================================

  describe "priorities" do
    it "tasks run before views (tasks < 10, views >= 10)" do
      r = setup_view_registry

      r.tasks.all? { |t| t.priority < 10 }.should be_true
      r.views.all? { |v| v.priority >= 10 }.should be_true
    end

    it "setup tasks have lowest priority (1-3)" do
      r = setup_view_registry
      setup_tasks = r.tasks.select { |t| t.name.starts_with?("Setup:") }

      setup_tasks.all? { |t| t.priority >= 1 && t.priority <= 3 }.should be_true
    end

    it "EXIF tasks run before cache tasks (4 < 5-6)" do
      r = setup_view_registry

      exif_task = r.tasks.find { |t| t.name == "EXIF: init all posts" }.not_nil!
      cache_tasks = r.tasks.select { |t| t.name.starts_with?("Cache:") }

      cache_tasks.all? { |t| t.priority > exif_task.priority }.should be_true
    end

    it "entity views have priority 10-19" do
      r = setup_view_registry
      entity_views = r.views.select { |v| v.name.includes?(": all pages") }

      entity_views.all? { |v| v.priority >= 10 && v.priority <= 19 }.should be_true
    end

    it "home views have priority 20-29" do
      r = setup_view_registry
      home_views = r.views.select { |v| v.name.starts_with?("Home:") }

      home_views.all? { |v| v.priority >= 20 && v.priority <= 29 }.should be_true
    end

    it "photo views have priority 30-39" do
      r = setup_view_registry
      photo_views = r.views.select { |v| v.name.starts_with?("Photo") }

      photo_views.all? { |v| v.priority >= 30 && v.priority <= 39 }.should be_true
    end

    it "stats views have priority 40-49" do
      r = setup_view_registry
      stats_views = r.views.select { |v| v.name.starts_with?("Stats:") }

      stats_views.all? { |v| v.priority >= 40 && v.priority <= 49 }.should be_true
    end

    it "index views have priority 60-69" do
      r = setup_view_registry
      index_views = r.views.select { |v| v.name.starts_with?("Index:") }

      index_views.all? { |v| v.priority >= 60 && v.priority <= 69 }.should be_true
    end

    it "static views have priority 89-99" do
      r = setup_view_registry
      static_views = r.views.select { |v| v.name.starts_with?("Static:") }

      static_views.all? { |v| v.priority >= 89 && v.priority <= 99 }.should be_true
    end

    it "feed views have priority 50-59" do
      r = setup_view_registry
      feed_views = r.views.select { |v| v.name.starts_with?("Feed:") }

      feed_views.all? { |v| v.priority >= 50 && v.priority <= 59 }.should be_true
    end

    it "debug views have priority 100+" do
      r = setup_view_registry
      debug_views = r.views.select { |v| v.name.starts_with?("Debug:") }

      debug_views.all? { |v| v.priority >= 100 }.should be_true
    end
  end

  # ============================================
  # Dependency Tests
  # ============================================

  describe "dependencies" do
    it "entity views depend on posts and yamls" do
      r = setup_view_registry
      entity_views = r.views.select { |v| v.name.includes?(": all pages") }

      entity_views.each do |view|
        view.depends_on.should contain(:posts)
        view.depends_on.should contain(:yamls)
      end
    end

    it "home views depend on posts only" do
      r = setup_view_registry
      home_views = r.views.select { |v| v.name.starts_with?("Home:") }

      home_views.each do |view|
        view.depends_on.should eq([:posts])
      end
    end

    it "photo views depend on exifs" do
      r = setup_view_registry
      photo_views = r.views.select { |v| v.name.starts_with?("Photo") }

      photo_views.each do |view|
        view.depends_on.should eq([:exifs])
      end
    end

    it "stats views depend on posts and yamls" do
      r = setup_view_registry
      stats_views = r.views.select { |v| v.name.starts_with?("Stats:") }

      stats_views.each do |view|
        view.depends_on.should contain(:posts)
        view.depends_on.should contain(:yamls)
      end
    end

    it "index views depend on posts and yamls" do
      r = setup_view_registry
      index_views = r.views.select { |v| v.name.starts_with?("Index:") }

      index_views.each do |view|
        view.depends_on.should contain(:posts)
        view.depends_on.should contain(:yamls)
      end
    end

    it "static markdown pages have no dependencies (always run)" do
      r = setup_view_registry

      new_more = r.views.find { |v| v.name == "Static: new more page" }.not_nil!
      about = r.views.find { |v| v.name == "Static: about page" }.not_nil!
      english = r.views.find { |v| v.name == "Static: english page" }.not_nil!

      new_more.depends_on.should eq([] of Symbol)
      about.depends_on.should eq([] of Symbol)
      english.depends_on.should eq([] of Symbol)
    end

    it "JS pages depend on posts" do
      r = setup_view_registry

      js_views = r.views.select { |v| v.name.starts_with?("Static: JS") }
      js_views.each do |view|
        view.depends_on.should eq([:posts])
      end
    end

    it "feed views (RSS, Atom, JSON) depend on posts and yamls" do
      r = setup_view_registry

      rss = r.views.find { |v| v.name == "Feed: RSS" }.not_nil!
      atom = r.views.find { |v| v.name == "Feed: Atom" }.not_nil!
      payload = r.views.find { |v| v.name == "Feed: payload JSON" }.not_nil!

      rss.depends_on.should eq([:posts, :yamls])
      atom.depends_on.should eq([:posts, :yamls])
      payload.depends_on.should eq([:posts, :yamls])
    end

    it "sitemap depends on posts only" do
      r = setup_view_registry

      sitemap = r.views.find { |v| v.name == "Feed: sitemap" }.not_nil!
      sitemap.depends_on.should eq([:posts])
    end

    it "robots.txt has no dependencies (always runs)" do
      r = setup_view_registry

      robots = r.views.find { |v| v.name == "Feed: robots.txt" }.not_nil!
      robots.depends_on.should eq([] of Symbol)
    end

    it "debug posts depends on posts" do
      r = setup_view_registry

      debug_posts = r.views.find { |v| v.name == "Debug: posts" }.not_nil!
      debug_posts.depends_on.should eq([:posts])
    end

    it "debug camera/EXIF views depend on exifs" do
      r = setup_view_registry

      camera = r.views.find { |v| v.name == "Debug: camera stuff" }.not_nil!
      missing = r.views.find { |v| v.name == "Debug: missing EXIF" }.not_nil!

      camera.depends_on.should eq([:exifs])
      missing.depends_on.should eq([:exifs])
    end
  end

  # ============================================
  # Query Tests - "What runs when X changes?"
  # ============================================

  describe "dependency queries" do
    it "returns correct entries when posts change" do
      r = setup_view_registry
      entries = r.entries_for(:posts)

      # Should include: setup tasks (always), entity views, home views, stats views, index views, JS pages
      names = entries.map(&.name)

      # Setup tasks always run
      names.should contain("Setup: dev render")
      names.should contain("Setup: copy assets")

      # Entity views
      # PHASE6_DEPRECATED: names.should contain("Towns: all pages") - migrated to AreaEntity
      names.should contain("Tags: all pages")

      # Home views
      names.should contain("Home: main page")
      names.should contain("Home: route map page")

      # Stats views

      # Should NOT include EXIF task or cache tasks that depend on :exifs
      names.should_not contain("EXIF: init all posts")
      # PHASE6_DEPRECATED: names.should_not contain("Cache: town photos") - removed
    end

    it "returns correct entries when yamls change" do
      r = setup_view_registry
      entries = r.entries_for(:yamls)
      names = entries.map(&.name)

      # Should include nav stats cache
      names.should contain("Cache: nav stats")

      # Should include entity views, stats views, index views
      # PHASE6_DEPRECATED: names.should contain("Towns: all pages") - migrated to AreaEntity
      names.should contain("Index: towns")

      # Should NOT include home views (they only depend on :posts)
      names.should_not contain("Home: main page")
    end

    it "returns correct entries when exifs change" do
      r = setup_view_registry
      entries = r.entries_for(:exifs)
      names = entries.map(&.name)

      # Should include EXIF task and cache tasks
      names.should contain("EXIF: init all posts")
      # PHASE6_DEPRECATED: names.should contain("Cache: town photos") - removed
      names.should contain("Cache: coord quant")

      # Should include photo views
      names.should contain("Photo galleries: all")
      names.should contain("Photo maps: all")

      # Should include debug camera/EXIF views
      names.should contain("Debug: camera stuff")
      names.should contain("Debug: missing EXIF")

      # Should NOT include entity views (they depend on posts/yamls, not exifs)
      # PHASE6_DEPRECATED: names.should_not contain("Towns: all pages") - migrated to AreaEntity
    end

    it "returns entries sorted by priority" do
      r = setup_view_registry
      entries = r.entries_for(:posts, :yamls)

      # Verify entries are sorted by priority
      priorities = entries.map(&.priority)
      priorities.should eq(priorities.sort)
    end

    it "names_depending_on returns just names for :posts" do
      r = setup_view_registry
      names = r.names_depending_on(:posts)

      names.should be_a(Array(String))
      # PHASE6_DEPRECATED: names.should contain("Towns: all pages") - migrated to AreaEntity
      names.should contain("Home: main page")
    end

    it "names_depending_on returns just names for :exifs" do
      r = setup_view_registry
      names = r.names_depending_on(:exifs)

      names.should contain("EXIF: init all posts")
      # PHASE6_DEPRECATED: names.should contain("Cache: town photos") - removed
      names.should contain("Cache: coord quant")
      names.should contain("Photo galleries: all")
      names.should contain("Photo maps: all")
    end
  end
end

describe ViewRegistry::Entry do
  describe "#should_run?" do
    it "returns true when dependency matches" do
      # Use registry to create entry (cleaner than direct construction)
      r = ViewRegistry.new
      r.task("Test", [:posts]) { |ctx| }
      entry = r.entries[0]

      entry.should_run?(Set{:posts}).should be_true
      entry.should_run?(Set{:posts, :yamls}).should be_true
    end

    it "returns false when dependency doesn't match" do
      r = ViewRegistry.new
      r.task("Test", [:posts]) { |ctx| }
      entry = r.entries[0]

      entry.should_run?(Set{:exifs}).should be_false
      entry.should_run?(Set{:yamls}).should be_false
    end

    it "returns true for empty depends_on (always run)" do
      r = ViewRegistry.new
      r.task("Test", [] of Symbol) { |ctx| }
      entry = r.entries[0]

      entry.should_run?(Set{:posts}).should be_true
      entry.should_run?(Set{:exifs}).should be_true
      entry.should_run?(Set(Symbol).new).should be_true
    end
  end
end
