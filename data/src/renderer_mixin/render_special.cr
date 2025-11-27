require "../views/special_view/payload_json_generator"
require "../views/special_view/ideas_json_generator"
require "../views/special_view/rss_generator"
require "../views/special_view/atom_generator"

module RendererMixin::RenderSpecial
  def render_all_special_views_post_and_yaml_related
    render_payload_json
    render_ideas_json
    render_rss
    render_atom
  end

  def render_all_special_views_post_related
    render_sitemap
    render_robot
  end

  def render_payload_json
    write_output(
      SpecialView::PayloadJsonGenerator.new(blog: @blog)
    )
  end

  def render_ideas_json
    write_output(
      SpecialView::IdeasJsonGenerator.new(blog: @blog)
    )
  end

  def render_rss
    view = SpecialView::RssGenerator.new(
      blog: @blog,
      posts: posts_descending,
      url: "/feed.xml",
      site_title: site_title,
      site_url: site_url,
      site_desc: site_desc,
      site_webmaster: site_email,
      site_language: "pl",
      updated_at: blog.post_collection.last_updated_at
    )

    write_output(view)
  end

  def render_atom
    view = SpecialView::AtomGenerator.new(
      blog: @blog,
      posts: posts_descending,
      url: "/feed_atom.xml",
      site_title: site_title,
      site_url: site_url,
      site_desc: site_desc,
      site_webmaster: site_email,
      author_name: site_author,
      site_guid: Digest::MD5.hexdigest(site_title).to_guid,
      site_language: "pl",
      updated_at: blog.post_collection.last_updated_at
    )

    write_output(view)
  end

  def render_sitemap
    view = Tremolite::Views::SiteMapGenerator.new(blog: @blog, url: "/sitemap.xml")
    write_output(view)
  end

  def render_robot
    view = Tremolite::Views::RobotGenerator.new
    write_output(view)
  end

  def site_title
    return @blog.data_manager.not_nil!["site.title"]
  end

  def site_url
    return @blog.data_manager.not_nil!["site.url"]
  end

  def site_email
    return @blog.data_manager.not_nil!["site.email"]
  end

  def site_author
    return @blog.data_manager.not_nil!["site.author"]
  end
end
