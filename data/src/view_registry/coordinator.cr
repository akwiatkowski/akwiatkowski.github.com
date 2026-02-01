# RenderCoordinator executes entries from the ViewRegistry
# based on what data has changed.
#
# Usage:
#   coordinator = RenderCoordinator.new(registry)
#   coordinator.render(context, changed: Set{:posts, :yamls})
#
class RenderCoordinator
  Log = ::Log.for(self)

  getter registry : ViewRegistry

  def initialize(@registry)
  end

  # Main entry point - render entries based on what changed
  def render(context : RenderContext, changed : Set(Symbol))
    to_run = @registry.entries_for(*changed.to_a)

    Log.info { "RenderCoordinator: #{to_run.size} entries to run (#{changed.join(", ")} changed)" }

    to_run.each_with_index do |entry, i|
      run_entry(entry, context, i + 1, to_run.size)
    end

    Log.info { "RenderCoordinator: complete" }
  end

  # Convenience methods for common scenarios
  def render_all(context : RenderContext)
    render(context, Set{:posts, :yamls, :exifs})
  end

  def render_posts_changed(context : RenderContext)
    render(context, Set{:posts})
  end

  def render_yamls_changed(context : RenderContext)
    render(context, Set{:yamls})
  end

  def render_exifs_changed(context : RenderContext)
    render(context, Set{:exifs})
  end

  def render_posts_and_yamls_changed(context : RenderContext)
    render(context, Set{:posts, :yamls})
  end

  private def run_entry(entry : ViewRegistry::Entry, context : RenderContext, num : Int32, total : Int32)
    label = "[#{num}/#{total}] [#{entry.type_label}] #{entry.name}"

    Log.info { "#{label} - START" }
    start_time = Time.monotonic

    begin
      entry.block.call(context)
    rescue ex
      Log.error { "#{label} - FAILED: #{ex.message}" }
      raise ex
    end

    elapsed = Time.monotonic - start_time
    Log.info { "#{label} - DONE (#{elapsed.total_milliseconds.round(2)}ms)" }
  end
end
