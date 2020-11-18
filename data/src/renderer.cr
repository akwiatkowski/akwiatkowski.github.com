require "./views/base_view"
require "./views/page_view"
require "./views/wide_page_view"

require "./views/home_view"
require "./views/portfolio_view"

require "./views/paginated_post_list_view"
require "./views/map_view"
require "./views/photo_map_html_view"
require "./views/photo_map_svg_view"
require "./views/planner_view"
require "./views/tag_view"
require "./views/tag_masonry_view"
require "./views/town_view"
require "./views/voivodeship_view"
require "./views/voivodeship_masonry_view"
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
require "./views/burnout_stat_view"
require "./views/gallery_view"
require "./views/tag_gallery_view"
require "./views/lens_gallery_view"
require "./views/towns_history_view"
require "./views/towns_timeline_view"
require "./views/timeline_list_view"
require "./views/exif_stats_view"

require "./views/payload_json_generator"
require "./views/rss_generator"
require "./views/atom_generator"

class Tremolite::Renderer
  # method run every time for test+dev stuff
  def dev_render
    render_burnout_stat_pages
  end

  def render_copy_assets
    copy_assets
  end

  def render_fast_only_post_related
    Log.debug { "render_fast_only_post_related START" }

    render_index
    render_paginated_list

    render_map
    render_pois

    render_sitemap
    render_robot

    Log.debug { "render_fast_only_post_related DONE" }
  end

  def render_fast_post_and_yaml_related
    Log.debug { "render_fast_post_and_yaml_related START" }

    render_summary_page
    render_year_stat_reports_pages
    render_burnout_stat_pages

    render_towns_history
    render_towns_timeline

    render_payload_json
    render_rss
    render_atom

    render_tags_pages

    render_lands_pages
    render_towns_pages
    render_todo_routes

    render_towns_index
    render_voivodeships_pages
    render_lands_index

    Log.debug { "render_fast_post_and_yaml_related DONE" }
  end

  def render_post(post : Tremolite::Post)
    view = PostView.new(blog: @blog, post: post)
    write_output(view)

    Log.debug { "render_post #{post.slug} DONE" }
  end

  def render_post_galleries_for_post(post)
    view_gallery = PostGalleryView.new(blog: @blog, post: post)
    write_output(view_gallery)
    Log.debug { "render_post #{post.slug} PostGalleryView" }

    view_gallery_stats = PostGalleryStatsView.new(blog: @blog, post: post)
    write_output(view_gallery_stats)
    Log.debug { "render_post #{post.slug} PostGalleryStatsView" }
  end

  # galleries which require exif data (photo lat/lon)
  # but require all photos in post content need to be initialized
  def render_galleries_pages
    render_gallery
    render_tag_galleries
    render_timeline_list
  end

  def render_fast_static_renders
    render_planner

    render_more_page
    render_about_page
    render_en_page
  end

  def render_exif_page
    render_portfolio

    render_photo_maps
    render_exif_stats

    # if exif was changed copy (no overwrite) images
    copy_post_photos
  end

  # simple renders

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

    Log.info { "Renderer: Rendered paginated list" }
  end

  def render_map
    view = MapView.new(blog: @blog, url: "/map")
    write_output(view)
  end

  # we will have not only 1 map but many: regular small, private big, ...
  # and maybe later I'll use this for voivodeship summary post
  def render_photo_maps
    # render_photo_maps_debug_post
    # render_photo_maps_debug_voivodeship
    # return

    render_photo_maps_for_tagged_photos
    render_photo_maps_voivodeships
    render_photo_maps_posts
    render_photo_maps_global
  end

  def render_photo_maps_debug_post
    slug = "2020-09-06-lodzkie-zakamarki-i-stare-domy"
    # slug = "2014-04-28-nadwarcianskim-szlakiem-rowerowym-oborniki-wronki"
    post = @blog.post_collection.posts.not_nil!.select do |post|
      post.slug == slug
    end.first

    render_photo_map_for_post(post)
    puts "SLEEPING"
    sleep 5
  end

  def render_photo_maps_debug_voivodeship
    @blog.data_manager.voivodeships.not_nil!.each do |voivodeship|
      next unless voivodeship.slug == "wielkopolskie"
      render_photo_map_for_voivodeship(voivodeship)
      puts "SLEEPING"
      sleep 5
    end
  end

  def render_photo_maps_voivodeships
    @blog.data_manager.voivodeships.not_nil!.each do |voivodeship|
      render_photo_map_for_voivodeship(voivodeship)
    end
  end

  def render_photo_maps_posts
    @blog.post_collection.posts.not_nil!.each do |post|
      if post.self_propelled? && post.detailed_routes && post.detailed_routes.not_nil!.size > 0
        render_photo_map_for_post(post)
      end
    end
  end

  def render_photo_map_for_post(post : Tremolite::Post)
    # TODO refactor post coords into something not ugly

    if post.detailed_routes.not_nil![0].route.size > 0
      Log.debug { "render_photo_maps_posts #{post.slug}" }

      # sometime I take photos from train and we want to have detailed
      # route map (big zoom) so we must remove photos taken from non route
      # places
      coord_range = PostRouteObject.array_to_coord_range(
        array: post.detailed_routes.not_nil!,
      )
      # only_types: ["hike", "bicycle", "train", "car", "air"]
      # lets accept all types for now

      autozoom_value = Map::TilesLayer.ideal_zoom(
        coord_range: coord_range.not_nil!,
        min_diagonal: 800,
        max_diagonal: 4200,
      )

      if autozoom_value
        post_map_view = PhotoMapSvgView.new(
          blog: @blog,
          url: "/photo_map/for_post/#{post.slug}.svg",
          zoom: autozoom_value.not_nil!,
          quant_size: Map::DEFAULT_POST_PHOTO_SIZE,
          post_slugs: [post.slug],
          coord_range: coord_range,
          do_not_crop_routes: true,
          render_photos_out_of_route: true,
          photo_direct_link: true,
        )
        write_output(post_map_view)
        Log.debug { "#{post.slug} - render_photo_maps_posts done" }
      else
        Log.warn { "#{post.slug} - autozoom_value could not calculate" }
      end
    else
      Log.debug { "#{post.slug} - no coords" }
    end
  end

  def render_photo_map_for_voivodeship(voivodeship : VoivodeshipEntity)
    # select posts in voivodeship
    # and render mini-map (not so mini)
    Log.debug { "render_photo_maps_voivodeships #{voivodeship.slug}" }

    # used for photos
    # TODO maybe use similar for routes but it will require some work
    voivodeship_coord_range = CoordRange.new(voivodeship)

    # for now select post slugs assigned for that voivodeship
    post_slugs = @blog.post_collection.posts.select do |post|
      post.was_in_voivodeship(voivodeship)
    end.map do |post|
      post.slug
    end

    voivodeship_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/for_voivodeship/#{voivodeship.slug}.svg",
      zoom: Map::DEFAULT_VOIVODESHIP_ZOOM,
      quant_size: Map::DEFAULT_VOIVODESHIP_PHOTO_SIZE,
      coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    write_output(voivodeship_view)

    voivodeship_small_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/for_voivodeship/#{voivodeship.slug}_small.svg",
      zoom: Map::DEFAULT_VOIVODESHIP_SMALL_ZOOM,
      quant_size: Map::DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE,
      coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    write_output(voivodeship_small_view)
  end

  # global... lol, only Poland
  def render_photo_maps_global
    overall_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/all_overall.svg",
      zoom: Map::DEFAULT_OVERALL_ZOOM,
      quant_size: Map::DEFAULT_OVERALL_PHOTO_SIZE,
    )
    write_output(overall_view)

    small_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/all_small.svg",
      zoom: Map::DEFAULT_SMALL_ZOOM,
      quant_size: Map::DEFAULT_SMALL_PHOTO_SIZE,
    )
    write_output(small_view)

    deailed_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/all_detailed.svg",
      zoom: Map::DEFAULT_DETAILED_ZOOM,
      quant_size: Map::DEFAULT_DETAILED_PHOTO_SIZE,
    )
    write_output(deailed_view)

    html_view = PhotoMapHtmlView.new(
      blog: @blog,
      url: "/photo_map",
      svg_url: overall_view.url
    )
    write_output(html_view)
  end

  def render_photo_maps_for_tagged_photos
    photo_entities = @blog.data_manager.exif_db.all_flatten_photo_entities.select do |photo_entity|
      photo_entity.tags.includes?("cat")
    end

    overall_view = PhotoMapSvgView.new(
      blog: @blog,
      url: "/photo_map/for_tag/cat.svg",
      zoom: Map::DEFAULT_TAG_ZOOM,
      quant_size: Map::DEFAULT_TAG_PHOTO_SIZE,
      photo_entities: photo_entities,
      render_routes: false,
    )
    write_output(overall_view)
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
      site_desc: site_desc,
      site_webmaster: @blog.data_manager.not_nil!["site.email"],
      site_language: "pl",
      updated_at: blog.post_collection.last_updated_at
    )

    write_output(view)
  end

  # overall site desc string
  @site_desc : String?

  def site_desc
    unless @site_desc
      posts = @blog.post_collection.posts.select { |post| post.trip? }
      bicycle_posts = posts.select { |post| post.bicycle? }
      hike_posts = posts.select { |post| post.hike? }

      bicycle_km = bicycle_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum
      hike_km = hike_posts.map { |post| post.distance }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_hours = posts.map { |post| post.time_spent }.select { |v| v }.map { |v| v.as(Float64) }.sum

      total_km = bicycle_km + hike_km

      s = @blog.data_manager.not_nil!["site.desc"].to_s
      {
        "total_km"    => total_km.to_i,
        "total_hours" => total_hours.to_i,
        "bicycle_km"  => bicycle_km.to_i,
        "hike_km"     => hike_km.to_i,
      }.each do |key, value|
        s = s.gsub("{{#{key}}}", value.to_s)
      end

      @site_desc = s
    end

    return @site_desc.to_s
  end

  def render_atom
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }
    view = AtomGenerator.new(
      blog: @blog,
      posts: posts,
      url: "/feed_atom.xml",
      site_title: @blog.data_manager.not_nil!["site.title"],
      site_url: @blog.data_manager.not_nil!["site.url"],
      site_desc: site_desc,
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

      masonry_view = TagMasonryView.new(blog: @blog, tag: tag)
      write_output(masonry_view)
    end
    Log.info { "Renderer: Tags finished" }
  end

  def render_lands_pages
    blog.data_manager.not_nil!.lands.not_nil!.each do |land|
      view = LandView.new(blog: @blog, land: land)
      write_output(view)
    end
    Log.info { "Renderer: Lands finished" }
  end

  def render_towns_pages
    blog.data_manager.not_nil!.towns.not_nil!.each do |town|
      view = TownView.new(blog: @blog, town: town)
      write_output(view)

      # XXX move later to somewhere else
      town.validate(@blog.validator.not_nil!)
    end
    Log.info { "Renderer: Towns finished" }
  end

  def render_voivodeships_pages
    blog.data_manager.not_nil!.voivodeships.not_nil!.each do |voivodeship|
      view = VoivodeshipView.new(blog: @blog, voivodeship: voivodeship)
      write_output(view)

      masonry_view = VoivodeshipMasonryView.new(blog: @blog, voivodeship: voivodeship)
      write_output(masonry_view)
    end
    Log.info { "Renderer: Voivodeships finished" }
  end

  def render_posts
    blog.post_collection.posts.each do |post|
      render_post(post)
    end
    Log.info { "Renderer: Posts finished" }
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

  def render_burnout_stat_pages
    view = BurnoutStatView.new(blog: @blog)
    write_output(view)
  end

  def render_gallery
    view = GalleryView.new(blog: @blog)
    write_output(view)
  end

  def render_tag_galleries
    # TODO get all tags from array of PhotoEntity
    ["cat", "portfolio"].each do |tag|
      view = TagGalleryView.new(blog: @blog, tag: tag)
      write_output(view)
    end
  end

  def render_lens_galleries
    # only for predefined lenses
    ExifEntity::LENS_NAMES.each do |lens|
      view = LensGalleryView.new(blog: @blog, lens: lens, tags: ["good", "best"])
      write_output(view)
    end
  end

  def render_timeline_list
    view = TimelineList.new(blog: @blog)
    write_output(view)
  end

  def render_portfolio
    view = PortfolioView.new(blog: @blog, url: "/portfolio")
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

  private def copy_post_photos
    command = "rsync -av #{blog.data_path}/images/ #{blog.public_path}/images/"
    `#{command}`
  end
end
