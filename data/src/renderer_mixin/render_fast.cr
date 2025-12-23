require "../views/post_list_view/all"
require "../views/static_view/all"
require "../views/dynamic_view/summary_view"
require "../views/dynamic_view/timeline_view"
require "../views/dynamic_view/year_stat_report_view"
require "../views/dynamic_view/burnout_stat_view"
require "../views/dynamic_view/towns_history_view"
require "../views/dynamic_view/towns_timeline_view"

module RendererMixin::RenderFast
  def render_home
    # DEPRECATED
    # write_output(
    #   PostListView::HomeMasonryView.new(
    #     blog: blog,
    #     url: "/old"
    #   )
    # )
  end

  def render_home_new
    write_output(
      PostListView::CollectionDynamicView.new(
        blog: blog,
        url: "/"
      )
    )
  end

  def render_map
    write_output(
      StaticView::MapView.new(
        blog: blog,
        url: "/mapa.html"
      )
    )
  end

  def render_ideas
    write_output(
      StaticView::IdeasView.new(
        blog: blog,
        url: "pomysly.html"
      )
    )
  end

  def render_more
    view = MarkdownPageView.new(
      blog: blog,
      url: "/wiecej.html",
      file: "more",
      image_url: blog.data_manager.not_nil!["more.backgrounds"],
      title: blog.data_manager.not_nil!["more.title"],
      subtitle: blog.data_manager.not_nil!["more.subtitle"]
    )
    write_output(view)
  end

  def render_about
    view = MarkdownPageView.new(
      blog: blog,
      url: "/o_mnie.html",
      file: "about",
      image_url: blog.data_manager.not_nil!["about.backgrounds"],
      title: blog.data_manager.not_nil!["about.title"],
      subtitle: blog.data_manager.not_nil!["about.subtitle"]
    )
    write_output(view)
  end

  def render_en
    view = MarkdownPageView.new(
      blog: blog,
      url: "/en/index.html",
      file: "en",
      image_url: blog.data_manager.not_nil!["en.backgrounds"],
      title: blog.data_manager.not_nil!["en.title"],
      subtitle: blog.data_manager.not_nil!["en.subtitle"]
    )
    write_output(view)
  end

  # TODO is it usable?
  def render_summary
    write_output(
      DynamicView::SummaryView.new(
        blog: blog,
        url: "/zestawienie.html"
      )
    )
  end

  # TODO is it usable?
  def render_timeline
    write_output(
      DynamicView::TimelineList.new(
        blog: @blog
      )
    )
  end

  def render_year_stat_reports
    years = blog.post_collection.posts.map(&.time).map(&.year).uniq
    years = years.select { |year| Time.local.year >= year }
    years.each do |year|
      view = DynamicView::YearStatReportView.new(
        blog: blog,
        year: year,
        all_years: years
      )
      write_output(view)
    end
  end

  def render_burnout_stat
    write_output(
      DynamicView::BurnoutStatView.new(
        blog: @blog
      )
    )
  end

  def render_towns_history
    write_output(
      DynamicView::TownsHistoryView.new(
        blog: blog,
        url: "/gminy/historia.html"
      )
    )
  end

  def render_towns_timeline
    write_output(
      DynamicView::TownsTimelineView.new(
        blog: blog,
        url: "/gminy/chronologicznie.html"
      )
    )
  end

  def render_pois
    write_output(
      PoisView.new(
        blog: blog,
        url: "/pois.html"
      )
    )
  end
end
