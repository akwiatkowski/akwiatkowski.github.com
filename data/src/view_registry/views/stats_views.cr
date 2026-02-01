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
# View classes used: DynamicView::SummaryView, YearStatReportView,
# BurnoutStatView, TownsHistoryView, TownsTimelineView
# (loaded via renderer.cr)

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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: summary page", [:posts, :yamls], priority: 40) do |ctx|
    ViewRegistry::Log.info { "Rendering summary page" }
    ctx.write_output(DynamicView::SummaryView.new(blog: ctx.blog, url: "/zestawienie.html"))
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
  # Note: Generates multiple pages (one per year)
  #
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: year reports", [:posts, :yamls], priority: 41) do |ctx|
    ViewRegistry::Log.info { "Rendering year stat reports" }
    years = ctx.years
    years.each do |year|
      ctx.write_output(DynamicView::YearStatReportView.new(blog: ctx.blog, year: year, all_years: years))
    end
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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: burnout", [:posts, :yamls], priority: 42) do |ctx|
    ViewRegistry::Log.info { "Rendering burnout stats page" }
    ctx.write_output(DynamicView::BurnoutStatView.new(blog: ctx.blog))
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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: towns history", [:posts, :yamls], priority: 43) do |ctx|
    ViewRegistry::Log.info { "Rendering towns history page" }
    ctx.write_output(DynamicView::TownsHistoryView.new(blog: ctx.blog, url: "/gminy/historia.html"))
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
  # Dependencies: [:posts, :yamls]
  #
  r.register("Stats: towns timeline", [:posts, :yamls], priority: 44) do |ctx|
    ViewRegistry::Log.info { "Rendering towns timeline page" }
    ctx.write_output(DynamicView::TownsTimelineView.new(blog: ctx.blog, url: "/gminy/chronologicznie.html"))
  end
end
