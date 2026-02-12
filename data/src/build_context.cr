# BuildContext extends RenderContext with write/mutation methods
# used by pipeline internals (registry blocks, post renderer, coordinator).
#
# Views receive `context : RenderContext` and cannot call render_and_write etc.
# BuildContext passes via Crystal subtyping — zero view changes needed.
#
require "./render_context"

class BuildContext < RenderContext
  # Render a view and write it to the output directory
  def render_and_write(view)
    blog.renderer.render_view(view)
  end

  def setup_dev_output
    blog.renderer.dev_render
  end

  def copy_assets_and_photos
    blog.renderer.copy_assets_and_photos
  end
end
