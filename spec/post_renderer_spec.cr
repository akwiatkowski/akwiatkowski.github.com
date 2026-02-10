require "./spec_helper"
require "../data/src/commands/base"

describe PostRenderer do
  # Use a shared blog instance for all tests (expensive to create)
  blog = Commands.init_blog("dev")
  ctx = RenderContext.new(blog)
  image_resizer = blog.image_resizer.not_nil!
  exif_db = blog.data_manager.exif_db
  photo_analysis_cache = blog.data_manager.photo_analysis_cache

  describe "#initialize" do
    it "creates with ctx, image_resizer, exif_db, and photo_analysis_cache" do
      renderer = PostRenderer.new(
        ctx: ctx,
        image_resizer: image_resizer,
        exif_db: exif_db,
        photo_analysis_cache: photo_analysis_cache,
      )
      renderer.should be_a(PostRenderer)
    end
  end

  describe "#render_with_galleries" do
    it "does nothing for empty post array" do
      renderer = PostRenderer.new(
        ctx: ctx,
        image_resizer: image_resizer,
        exif_db: exif_db,
        photo_analysis_cache: photo_analysis_cache,
      )
      # Should return immediately without errors
      renderer.render_with_galleries([] of Tremolite::Post, hide_not_finished: false)
    end
  end

  describe "#render_content_only" do
    it "does nothing for empty post array" do
      renderer = PostRenderer.new(
        ctx: ctx,
        image_resizer: image_resizer,
        exif_db: exif_db,
        photo_analysis_cache: photo_analysis_cache,
      )
      # Should return immediately without errors
      renderer.render_content_only([] of Tremolite::Post, hide_not_finished: false)
    end
  end
end
