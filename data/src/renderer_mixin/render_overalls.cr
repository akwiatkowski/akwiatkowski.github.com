module RendererMixin::RenderOveralls
  def render_all_model_pages
    render_lands_pages
    render_towns_pages
    render_voivodeships_pages
    render_tags_pages

    render_towns_index
    render_lands_index
  end

  def render_all_views_post_related
    render_home_new
    render_map
    render_pois
  end

  def render_js_pages
    render_js_ideas
    render_js_timeline
    render_js_panoramio
    render_js_exif_stats
  end

  def render_fast_static_renders
    render_more
    render_about
    render_en
  end

  def render_all_views_post_and_yaml_related
    render_summary
    render_year_stat_reports
    render_burnout_stat

    render_towns_history
    render_towns_timeline
  end
end
