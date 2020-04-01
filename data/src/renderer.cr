require "./views/base_view"
require "./views/page_view"
require "./views/wide_page_view"

require "./views/home_view"
require "./views/paginated_post_list_view"
require "./views/map_view"
require "./views/photo_map_view"
require "./views/planner_view"
require "./views/tag_view"
require "./views/town_view"
require "./views/land_view"
require "./views/post_view"
require "./views/post_gallery_view"
require "./views/post_gallery_stats_view"
require "./views/summary_view"
require "./views/markdown_page_view"
require "./views/todos_view"
require "./views/pois_view"
require "./views/towns_index_view"
require "./views/lands_index_view"
require "./views/year_stat_report_view"
require "./views/gallery_view"
require "./views/tag_gallery_view"
require "./views/towns_history_view"
require "./views/towns_timeline_view"
require "./views/timeline_list_view"
require "./views/exif_stats_view"

require "./views/payload_json_generator"
require "./views/rss_generator"
require "./views/atom_generator"

class Tremolite::Renderer
  def render_all
    return
    
    watchers = all_mod_watchers
    watchers_static = watchers[:static].as(Array(String))
    watchers_posts_mtime = watchers[:posts_mtime].as(Array(String))
    watchers_photo_count = watchers[:photo_count].as(Array(String))

    # TODO 1) add viewer classes changes

    # TODO 2) add html includes changes

    # 3) update posts (only)
    if watchers_static.includes?(ModWatcher::KEY_POSTS_FILES) || watchers_static.includes?(ModWatcher::KEY_YAMLS)
      @logger.debug("#{self.class} mod watcher: #{ModWatcher::KEY_POSTS_FILES} | #{ModWatcher::KEY_YAMLS}")

      # low processing fast renders
      render_post_related_fast_renders

      # posts, w/o galleries
      render_only_posts

      # update list of posts related to town, voivodeship, tag, ...
      render_yaml_based_pages
    end

    # 3b) added photos to directory or added to post content, render galleries pages
    if watchers_photo_count.size > 0
      @logger.debug("#{self.class} mod watcher: #{watchers_photo_count.size} photo_count")

      # iterate posts
      watchers_photo_count.each do |post_slug|
        posts_with_changes_photos = blog.post_collection.posts.select do |post|
          post.slug == post_slug
        end

        # all galleries pages
        posts_with_changes_photos.each do |post|
          render_post_galleries_for_post(post)
        end
      end

      # and update overall galleries pages
      render_galleries_pages
    end

    # 4) exif pages takes a lot of time but exif db is updated only
    # when I add photos
    if watchers_static.includes?(ModWatcher::KEY_EXIF_DB)
      @logger.debug("#{self.class} mod watcher: #{ModWatcher::KEY_EXIF_DB}")

      render_exif_page
    end

    render_fast_renders
  end

  def render_post_related_fast_renders
    render_index
    render_paginated_list

    render_map
    render_pois

    render_summary_page
    render_year_stat_reports_pages

    # it's post and town related
    # should not take much time but not sure
    render_towns_history
    render_towns_timeline

    render_payload_json
    render_rss
    render_atom

    render_sitemap
    render_robot
  end

  def render_fast_renders
    render_planner

    render_more_page
    render_about_page
    render_en_page
  end

  # render only regular post pages, it should be fast
  def render_only_posts
    @logger.debug("#{self.class}: render_only_posts")
    blog.post_collection.posts.each do |post|
      view = PostView.new(blog: @blog, post: post)
      write_output(view)
    end
  end

  def render_post_galleries_for_post(post)
    view_gallery = PostGalleryView.new(blog: @blog, post: post)
    write_output(view_gallery)
    @logger.debug("#{self.class}:render_post #{post.slug} PostGalleryView")

    view_gallery_stats = PostGalleryStatsView.new(blog: @blog, post: post)
    write_output(view_gallery_stats)
    @logger.debug("#{self.class}:render_post #{post.slug} PostGalleryStatsView")
  end

  # galleries which do not use exif
  def render_galleries_pages
    render_gallery
    render_tag_galleries

    render_timeline_list
  end

  def render_yaml_based_pages
    render_tags_pages

    render_lands_pages
    render_towns_pages
    render_todo_routes

    render_towns_index
    render_voivodeships_pages
    render_lands_index
  end

  def render_exif_page
    save_exif_entities
    render_photo_maps
    render_exif_stats
  end

  # end of render sets

  def render_only_posts
    @logger.debug("#{self.class}: render_only_posts")
    blog.post_collection.posts.each do |post|
      view = PostView.new(blog: @blog, post: post)
      write_output(view)
      @logger.debug("#{self.class}: #{post.slug} PostView")
    end
  end

  #

  def render_post_related_slow_renders(post_slugs : Array(String))
    render_posts
  end



  # single groups related, not good idea

  def render_exif_related_pages
    update_only_when_changed(ModWatcher::KEY_EXIF_DB) do



    end
  end


  # put not group renderer methods below

  def save_exif_entities
    @blog.data_manager.not_nil!.save_exif_entities
  end

  def render_index
    view = HomeView.new(blog: @blog, url: "/")
    write_output(view)
  end

  def render_paginated_list
    per_page = PaginatedPostListView::PER_PAGE
    i = 0
    total_count = blog.post_collection.posts.size

    posts_per_pages = Array(Array(Tremolite::Post)).new

    while i < total_count
      from_idx = i
      to_idx = i + per_page - 1

      posts = blog.post_collection.posts_from_latest[from_idx..to_idx]
      posts_per_pages << posts

      i += per_page
    end

    posts_per_pages.each_with_index do |posts, i|
      page_number = i + 1
      url = "/list/page/#{page_number}"
      url = "/list/" if page_number == 1

      # render and save
      view = PaginatedPostListView.new(
        blog: @blog,
        url: url,
        posts: posts,
        page: page_number,
        count: posts_per_pages.size
      )

      write_output(url, view.to_html)
    end

    @logger.info("Renderer: Rendered paginated list")
  end

  def render_map
    view = MapView.new(blog: @blog, url: "/map")
    write_output(view)
  end

  # we will have not only 1 map but many: regular small, private big, ...
  # and maybe later I'll use this for voivodeship summary post
  def render_photo_maps
    view = PhotoMapView.new(blog: @blog, url: "/photo_map")
    write_output(view)
  end

  def render_photo_map
    render_photo_maps
  end

  def render_planner
    view = PlannerView.new(blog: @blog, url: "/planner")
    write_output(view)
  end

  def render_todo_routes
    todos_all = @blog.data_manager.not_nil!.todo_routes.not_nil!

    # all
    todos = todos_all.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/", prechecked: TodosView::FILTER_CHECKED_STANDARD)
    write_output(view)

    # close - within 150 minutes of train
    todos = todos_all.select { |t| t.close? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/close", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # full_day - 150-270 (2.5-4.5h) minutes of train
    todos = todos_all.select { |t| t.full_day? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/full_day", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # external - >270 (4.5h) minutes of train
    todos = todos_all.select { |t| t.external? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/external", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # touring - longer than 140km
    todos = todos_all.select { |t| t.touring? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/touring", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "from"
    todos = todos_all.sort { |a, b| a.from <=> b.from }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/from", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "transport_total_cost_minutes"
    todos = todos_all.sort { |a, b| a.transport_total_cost_minutes <=> b.transport_total_cost_minutes }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/transport_cost", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # by major town near
    major_towns = @blog.data_manager.not_nil!.transport_pois.not_nil!.select(&.major)
    major_towns.each do |major_town|
      todos = todos_all.select { |todo_route|
        (todo_route.from_poi && todo_route.from_poi.not_nil!.closest_major_name == major_town.name) ||
          (todo_route.to_poi && todo_route.to_poi.not_nil!.closest_major_name == major_town.name)
      }
      url = "/todos/town/#{major_town.name.downcase.gsub(/\s/, "_")}"
      view = TodosView.new(blog: @blog, todos: todos, url: url, prechecked: TodosView::FILTER_CHECKED_ALL)
      write_output(view)
    end

    # notes from markdown
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/todos/notes",
      file: "todo_notes",
      image_url: @blog.data_manager.not_nil!["todos.backgrounds"],
      title: @blog.data_manager.not_nil!["todos.title"],
      subtitle: @blog.data_manager.not_nil!["todos.subtitle"]
    )
    write_output(view)
  end

  def render_payload_json
    view = PayloadJsonGenerator.new(blog: @blog, url: "/payload.json")
    write_output(view)
  end

  def render_rss
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }
    view = RssGenerator.new(
      blog: @blog,
      posts: posts,
      url: "/feed.xml",
      site_title: @blog.data_manager.not_nil!["site.title"],
      site_url: @blog.data_manager.not_nil!["site.url"],
      site_desc: @blog.data_manager.not_nil!["site.desc"],
      site_webmaster: @blog.data_manager.not_nil!["site.email"],
      site_language: "pl",
      updated_at: blog.post_collection.last_updated_at
    )

    write_output(view)
  end

  def render_atom
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }
    view = AtomGenerator.new(
      blog: @blog,
      posts: posts,
      url: "/feed_atom.xml",
      site_title: @blog.data_manager.not_nil!["site.title"],
      site_url: @blog.data_manager.not_nil!["site.url"],
      site_desc: @blog.data_manager.not_nil!["site.desc"],
      site_webmaster: @blog.data_manager.not_nil!["site.email"],
      author_name: @blog.data_manager.not_nil!["site.author"],
      site_guid: Digest::MD5.hexdigest(@blog.data_manager.not_nil!["site.title"]).to_guid,
      site_language: "pl",
      updated_at: blog.post_collection.last_updated_at
    )

    write_output(view)
  end

  def render_tags_pages
    blog.data_manager.not_nil!.tags.not_nil!.each do |tag|
      view = TagView.new(blog: @blog, tag: tag)
      write_output(view)
    end
    @logger.info("Renderer: Tags finished")
  end

  def render_lands_pages
    blog.data_manager.not_nil!.lands.not_nil!.each do |land|
      view = LandView.new(blog: @blog, land: land)
      write_output(view)
    end
    @logger.info("Renderer: Lands finished")
  end

  def render_towns_pages
    blog.data_manager.not_nil!.towns.not_nil!.each do |town|
      view = TownView.new(blog: @blog, town: town)
      write_output(view)

      # XXX move later to somewhere else
      town.validate(@blog.validator.not_nil!)
    end
    @logger.info("Renderer: Towns finished")
  end

  def render_voivodeships_pages
    blog.data_manager.not_nil!.voivodeships.not_nil!.each do |voivodeship|
      view = TownView.new(blog: @blog, town: voivodeship)
      write_output(view)
    end
    @logger.info("Renderer: Voivodeships (town) finished")
  end

  def render_posts
    blog.post_collection.posts.each do |post|
      render_post(post)
    end
    @logger.info("Renderer: Posts finished")
  end

  def render_post(post : Tremolite::Post)


    @logger.debug("#{self.class}:render_post #{post.slug} DONE")
  end

  def render_more_page
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/more",
      file: "more",
      image_url: @blog.data_manager.not_nil!["more.backgrounds"],
      title: @blog.data_manager.not_nil!["more.title"],
      subtitle: @blog.data_manager.not_nil!["more.subtitle"]
    )
    write_output(view)
  end

  def render_about_page
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/about",
      file: "about",
      image_url: @blog.data_manager.not_nil!["about.backgrounds"],
      title: @blog.data_manager.not_nil!["about.title"],
      subtitle: @blog.data_manager.not_nil!["about.subtitle"]
    )
    write_output(view)
  end

  def render_en_page
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/en",
      file: "en",
      image_url: @blog.data_manager.not_nil!["en.backgrounds"],
      title: @blog.data_manager.not_nil!["en.title"],
      subtitle: @blog.data_manager.not_nil!["en.subtitle"]
    )
    write_output(view)
  end

  def render_summary_page
    view = SummaryView.new(blog: @blog, url: "/summary")
    write_output(view)
  end

  def render_pois
    view = PoisView.new(blog: @blog, url: "/pois")
    write_output(view)
  end

  def render_towns_index
    view = TownsIndexView.new(blog: @blog, url: "/towns")
    write_output(view)
  end

  def render_towns_history
    view = TownsHistoryView.new(blog: @blog, url: "/towns/history")
    write_output(view)
  end

  def render_towns_timeline
    view = TownsTimelineView.new(blog: @blog, url: "/towns/timeline")
    write_output(view)
  end

  def render_lands_index
    view = LandsIndexView.new(blog: @blog, url: "/lands")
    write_output(view)
  end

  def render_year_stat_reports_pages
    years = @blog.post_collection.posts.map(&.time).map(&.year).uniq
    years = years.select { |year| Time.local.year >= year }
    years.each do |year|
      view = YearStatReportView.new(blog: @blog, year: year, all_years: years)
      write_output(view)
    end
  end

  def render_gallery
    view = GalleryView.new(blog: @blog)
    write_output(view)
  end

  def render_tag_galleries
    # TODO
    ["cat"].each do |tag|
      view = TagGalleryView.new(blog: @blog, tag: tag)
      write_output(view)
    end
  end

  def render_timeline_list
    view = TimelineList.new(blog: @blog)
    write_output(view)
  end

  def render_exif_stats
    view = ExifStatsView.new(blog: @blog, url: "/exif_stats")
    write_output(view)

    tags = ["bicycle", "hike", "photo", "train"]

    tags.each do |tag|
      view_by_tag = ExifStatsView.new(
        blog: @blog,
        url: "/exif_stats",
        by_tag: tag
      )
      write_output(view_by_tag)
    end
  end

  def render_sitemap
    view = Tremolite::Views::SiteMapGenerator.new(blog: @blog, url: "/sitemap.xml")
    write_output(view)
  end

  def render_robot
    view = Tremolite::Views::RobotGenerator.new
    write_output(view)
  end

  private def clear
    # because there are some not rendered content in public and we
    # cannot allow to be removed
    raise Exception.new("`clear` is disabled")
  end

  # return Array(String) of all ModWatcher keys, posts, ...
  # to decide which renderers to run
  def all_mod_watchers
    @blog.mod_watcher.not_nil!.all_mod_watchers
  end
end
