# PostRenderer handles per-post rendering operations.
#
# This class encapsulates the logic for rendering individual posts,
# including image resizing, EXIF initialization, and gallery generation.
#
# There are two rendering modes:
# 1. With galleries - for posts where photos/EXIF changed
# 2. Content only - for posts where only markdown changed
#
# Usage:
#   renderer = PostRenderer.new(ctx: context, image_resizer: resizer, exif_db: db)
#   renderer.render_with_galleries(posts, hide_not_finished: false)
#   renderer.render_content_only(posts, hide_not_finished: false)
#
class PostRenderer
  include Profiled

  Log = ::Log.for(self)

  def initialize(
    @ctx : RenderContext,
    @image_resizer : Tremolite::ImageResizer,
    @exif_db : ExifDb,
    @photo_analysis_cache : PhotoAnalysisCache,
  )
  end

  # Render posts that need full gallery updates (photos/EXIF changed)
  #
  # This includes:
  # - Resizing images
  # - Initializing EXIF data
  # - Rendering the post article
  # - Rendering post galleries (GalleryView::PostView, PostGalleryStatsView)
  # - Saving EXIF cache
  #
  @[Profile(category: "posts")]
  def render_with_galleries(posts : Array(Tremolite::Post), hide_not_finished : Bool)
    return if posts.empty?

    Log.info { "Rendering #{posts.size} posts with galleries" }

    posts.each do |post|
      render_single_with_gallery(post, hide_not_finished)
    end

    Log.info { "Posts with galleries: complete" }
  end

  # Render posts that only need content updates (no gallery changes)
  #
  # This includes:
  # - Resizing images (in case new images added)
  # - Rendering the post article
  # - Saving EXIF cache
  #
  @[Profile(category: "posts")]
  def render_content_only(posts : Array(Tremolite::Post), hide_not_finished : Bool)
    return if posts.empty?

    Log.info { "Rendering #{posts.size} posts (content only)" }

    posts.each do |post|
      render_single_content_only(post, hide_not_finished)
    end

    Log.info { "Posts content only: complete" }
  end

  private def render_single_with_gallery(post : Tremolite::Post, hide_not_finished : Bool)
    Log.debug { "#{post.slug} - resize images" }
    resize_images(post)

    Log.debug { "#{post.slug} - init EXIF" }
    init_exif(post)

    Log.debug { "#{post.slug} - init photo analysis" }
    init_photo_analysis(post)

    Log.debug { "#{post.slug} - render article" }
    render_article(post, hide_not_finished)

    Log.debug { "#{post.slug} - render galleries" }
    render_galleries(post)

    Log.debug { "#{post.slug} - save EXIF cache" }
    save_exif_cache(post)

    Log.debug { "#{post.slug} - save photo analysis cache" }
    save_photo_analysis_cache(post)

    Log.info { "#{post.slug} - DONE (with galleries)" }
  end

  private def render_single_content_only(post : Tremolite::Post, hide_not_finished : Bool)
    Log.debug { "#{post.slug} - resize images" }
    resize_images(post)

    Log.debug { "#{post.slug} - prepare content" }
    post.content_html

    Log.debug { "#{post.slug} - render article" }
    render_article(post, hide_not_finished)

    Log.debug { "#{post.slug} - save EXIF cache" }
    save_exif_cache(post)

    Log.debug { "#{post.slug} - save photo analysis cache" }
    save_photo_analysis_cache(post)

    Log.debug { "#{post.slug} - DONE (content only)" }
  end

  # ============================================
  # Individual operations
  # ============================================

  private def resize_images(post : Tremolite::Post)
    @image_resizer.resize_all_images_for_post(
      post: post,
      overwrite: false
    )
  end

  private def init_exif(post : Tremolite::Post)
    @exif_db.initialize_post_photos_exif(post)
  end

  private def init_photo_analysis(post : Tremolite::Post)
    filenames = post.published_photo_entities.map(&.image_filename) +
                post.list_of_uploaded_photos
    @photo_analysis_cache.process_photos(post.slug, filenames.uniq)
  end

  private def render_article(post : Tremolite::Post, hide_not_finished : Bool)
    @ctx.write_output(PostView::ArticleView.new(
      context: @ctx,
      post: post,
      hide_not_finished: hide_not_finished
    ))
  end

  private def render_galleries(post : Tremolite::Post)
    @ctx.write_output(GalleryView::PostView.new(context: @ctx, post: post))
    @ctx.write_output(PostGalleryStatsView.new(context: @ctx, post: post))
  end

  private def save_exif_cache(post : Tremolite::Post)
    @exif_db.save_cache(post.slug)
  end

  private def save_photo_analysis_cache(post : Tremolite::Post)
    @photo_analysis_cache.save_cache(post.slug)
  end
end
