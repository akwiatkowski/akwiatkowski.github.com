# Stats Views
# ===========
#
# These views render statistics and report pages with significant
# data processing. They aggregate post data into summaries.
#
# Current views:
# 1. Summary page - /zestawienie.html (priority: 40)
# 2. Year reports - /rok/{year}.html (priority: 41)
# 3. Burnout stats - /burnout.html (priority: 42)
# 4. Towns history - /gminy/historia.html (priority: 43)
# 5. Towns timeline - /gminy/chronologicznie.html (priority: 44)
#
# Dependencies: [:posts, :yamls]
# - Posts: source data for statistics
# - Yamls: entity definitions for grouping
#
# Priority: 40-49 (after entity views, before feeds)
#
# Source: Extracted from render_fast.cr (render_all_views_post_and_yaml_related)
#
def register_stats_views(r : ViewRegistry)
  # ============================================
  # View: Summary Page
  # ============================================
  #
  # Renders the main summary/statistics page with
  # aggregated data from all posts.
  #
  # URL: /zestawienie.html
  # View class: DynamicView::SummaryView
  #
  # Original code (render_fast.cr:102-109):
  #   def render_summary
  #     write_output(DynamicView::SummaryView.new(blog: blog, url: ...))
  #   end
  #
  # Called from: render_all_views_post_and_yaml_related (render_overalls.cr:32)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: summary page", [:posts, :yamls], priority: 40) do |ctx|
    ViewRegistry::Log.info { "Rendering summary page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_summary
  end

  # ============================================
  # View: Year Reports
  # ============================================
  #
  # Renders per-year statistics pages showing annual
  # summaries of posts, distances, etc.
  #
  # URL pattern: /rok/{year}.html
  # View class: DynamicView::YearStatReportView
  #
  # Original code (render_fast.cr:111-122):
  #   def render_year_stat_reports
  #     years = blog.post_collection.posts.map(&.time).map(&.year).uniq
  #     years.each do |year|
  #       view = DynamicView::YearStatReportView.new(...)
  #       write_output(view)
  #     end
  #   end
  #
  # Called from: render_all_views_post_and_yaml_related (render_overalls.cr:33)
  #
  # Note: Generates multiple pages (one per year)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: year reports", [:posts, :yamls], priority: 41) do |ctx|
    ViewRegistry::Log.info { "Rendering year stat reports" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_year_stat_reports
  end

  # ============================================
  # View: Burnout Stats
  # ============================================
  #
  # Renders burnout/activity statistics showing posting
  # frequency and gaps.
  #
  # URL: /burnout.html
  # View class: DynamicView::BurnoutStatView
  #
  # Original code (render_fast.cr:124-130):
  #   def render_burnout_stat
  #     write_output(DynamicView::BurnoutStatView.new(blog: @blog))
  #   end
  #
  # Called from: render_all_views_post_and_yaml_related (render_overalls.cr:34)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: burnout", [:posts, :yamls], priority: 42) do |ctx|
    ViewRegistry::Log.info { "Rendering burnout stats page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_burnout_stat
  end

  # ============================================
  # View: Towns History
  # ============================================
  #
  # Renders the history of visited towns showing
  # first visit dates and accumulation over time.
  #
  # URL: /gminy/historia.html
  # View class: DynamicView::TownsHistoryView
  #
  # Original code (render_fast.cr:132-139):
  #   def render_towns_history
  #     write_output(DynamicView::TownsHistoryView.new(blog: blog, url: ...))
  #   end
  #
  # Called from: render_all_views_post_and_yaml_related (render_overalls.cr:36)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: towns history", [:posts, :yamls], priority: 43) do |ctx|
    ViewRegistry::Log.info { "Rendering towns history page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_towns_history
  end

  # ============================================
  # View: Towns Timeline
  # ============================================
  #
  # Renders a chronological timeline of town visits
  # showing when each town was first visited.
  #
  # URL: /gminy/chronologicznie.html
  # View class: DynamicView::TownsTimelineView
  #
  # Original code (render_fast.cr:141-148):
  #   def render_towns_timeline
  #     write_output(DynamicView::TownsTimelineView.new(blog: blog, url: ...))
  #   end
  #
  # Called from: render_all_views_post_and_yaml_related (render_overalls.cr:37)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: towns timeline", [:posts, :yamls], priority: 44) do |ctx|
    ViewRegistry::Log.info { "Rendering towns timeline page" }

    # Wrapper: calls existing mixin method
    ctx.blog.renderer.render_towns_timeline
  end
end
