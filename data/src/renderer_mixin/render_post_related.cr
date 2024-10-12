require "../views/post_list_view/paginated_list_view"
require "../views/post_list_view/new_posts_view"
require "../views/post_list_view/new_posts_masonry_view"
require "../views/dynamic_view/mountain_range_planner_view"
require "../views/post_view/article_view"
require "../views/dynamic_view/debug_post_view"

module RendererMixin::RenderPostRelated
  def render_fast_only_post_related
    Log.debug { "render_fast_only_post_related START" }

    render_all_special_views_post_related
    render_all_views_post_related

    render_posts_paginated_lists
    render_last_updated_posts

    render_debug_posts

    render_pois

    Log.debug { "render_fast_only_post_related DONE" }
  end

  def render_fast_post_and_yaml_related
    Log.debug { "render_fast_post_and_yaml_related START" }

    render_all_special_views_post_and_yaml_related
    render_all_views_post_and_yaml_related

    render_all_model_pages

    render_mountain_range_planner
    render_towns_history
    render_towns_timeline

    render_todo_routes

    ###

    render_towns_index
    render_lands_index

    Log.debug { "render_fast_post_and_yaml_related DONE" }
  end

  def render_posts_paginated_lists
    per_page = PostListView::PaginatedListView::PER_PAGE
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
      view = PostListView::PaginatedListView.new(
        blog: blog,
        url: url,
        posts: posts,
        page: page_number,
        count: posts_per_pages.size
      )

      write_output(view)
    end

    Log.info { "Renderer: Rendered paginated list" }
  end

  def render_posts
    blog.post_collection.posts.each do |post|
      render_post(post)
    end
    Log.info { "Renderer: Posts finished" }
  end

  def render_post(post : Tremolite::Post)
    view = PostView::ArticleView.new(
      blog: blog,
      post: post
    )
    write_output(view)

    Log.debug { "render_post #{post.slug} DONE" }
  end

  def render_mountain_range_planner
    write_output(
      DynamicView::MountainRangePlannerView.new(
        blog: blog,
        url: "/mountain_range_planner"
      )
    )
  end

  def render_debug_posts
    write_output(
      DynamicView::DebugPostView.new(
        blog: blog
      )
    )
  end

  def render_last_updated_posts
    write_output(PostListView::NewPostsView.new(blog: blog))
    write_output(PostListView::NewPostsMasonryView.new(blog: blog))
    Log.info { "New posts rendered" }
  end
end
