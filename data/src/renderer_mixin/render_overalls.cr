module RendererMixin::RenderOveralls
  def render_all_model_pages
    render_lands_pages
    render_towns_pages
    render_tags_pages
  end

  def render_all_views_post_related
    render_home
    render_map
  end

  def render_fast_static_renders
    render_more
    render_about
    render_en
  end

  def render_all_views_post_and_yaml_related
    render_summary # TODO
    render_year_stat_reports
    render_burnout_stat # TODO
  end

  def render_galleries_pages
    render_timeline # TODO

    render_all_photo_related # TODO keep in mind it should only be run after exif is loaded
  end
end
