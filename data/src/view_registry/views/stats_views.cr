# Stats Views
# ===========
#
# These views render statistics and report pages with significant
# data processing. They aggregate post data into summaries.
#
# Current views:
# 1. Year reports - /rok/{year}.html (priority: 41)
# 2. Burnout stats - /burnout.html (priority: 42)
# 3. Towns history - /gminy/historia.html (priority: 43)
# 4. Towns timeline - /gminy/chronologicznie.html (priority: 44)
#
# Dependencies: [:posts, :yamls]
# - Posts: source data for statistics
# - Yamls: entity definitions for grouping
#
# Priority: 40-49 (after entity views, before feeds)
#
# View classes used: DynamicView::YearStatReportView,
# BurnoutStatView, TownsHistoryView, TownsTimelineView
# (loaded via renderer.cr)

def register_stats_views(r : ViewRegistry)
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
      ctx.render_and_write(DynamicView::YearStatReportView.new(context: ctx, year: year, all_years: years))
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
    ctx.render_and_write(DynamicView::BurnoutStatView.new(context: ctx))
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
    ctx.render_and_write(DynamicView::TownsHistoryView.new(context: ctx))
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
    ctx.render_and_write(DynamicView::TownsTimelineView.new(context: ctx))
  end
end
