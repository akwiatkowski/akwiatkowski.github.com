# ViewRegistry provides a declarative way to register views and tasks
# with their dependencies. The coordinator uses this to determine
# what to render when data changes.
#
# Usage:
#   registry = ViewRegistry.new
#   registry.task("Load EXIF", [:exifs], priority: 1) { |ctx| ... }
#   registry.register("Town pages", [:posts, :yamls]) { |ctx| ... }
#
#   # Query what runs when posts change
#   registry.entries_for(:posts)
#
class ViewRegistry
  Log = ::Log.for(self)

  alias EntryBlock = Proc(RenderContext, Nil)

  struct Entry
    property name : String
    property depends_on : Array(Symbol)
    property block : EntryBlock
    property priority : Int32
    property is_task : Bool

    def initialize(@name, @depends_on, @block, @priority = 100, @is_task = false)
    end

    def should_run?(changed : Set(Symbol)) : Bool
      # Empty depends_on means always run
      return true if depends_on.empty?
      depends_on.any? { |dep| changed.includes?(dep) }
    end

    def type_label : String
      is_task ? "task" : "view"
    end
  end

  getter entries : Array(Entry) = [] of Entry

  # Register a view (renders output)
  def register(
    name : String,
    depends_on : Array(Symbol),
    priority : Int32 = 100,
    &block : RenderContext -> Nil
  ) : self
    @entries << Entry.new(name, depends_on, block, priority, is_task: false)
    self
  end

  # Register a task (prepares data, no output)
  def task(
    name : String,
    depends_on : Array(Symbol),
    priority : Int32 = 1,
    &block : RenderContext -> Nil
  ) : self
    @entries << Entry.new(name, depends_on, block, priority, is_task: true)
    self
  end

  # ============================================
  # Query methods
  # ============================================

  # Get entries that should run when given dependencies change
  def entries_for(*dependencies : Symbol) : Array(Entry)
    entries_for(dependencies.to_set)
  end

  # Get entries that should run when given dependencies change (Set version)
  def entries_for(dep_set : Set(Symbol)) : Array(Entry)
    @entries.select(&.should_run?(dep_set)).sort_by(&.priority)
  end

  # Get just the names of views/tasks that depend on something
  def names_depending_on(dep : Symbol) : Array(String)
    @entries.select { |e| e.depends_on.includes?(dep) }.map(&.name)
  end

  # Get only tasks
  def tasks : Array(Entry)
    @entries.select(&.is_task)
  end

  # Get only views (not tasks)
  def views : Array(Entry)
    @entries.reject(&.is_task)
  end

  # ============================================
  # Debug / Documentation helpers
  # ============================================

  def print_dependency_matrix(io : IO = STDOUT)
    io.puts "Entry                            | Type | Pri | posts | yamls | exifs |"
    io.puts "---------------------------------|------|-----|-------|-------|-------|"
    @entries.sort_by(&.priority).each do |entry|
      type = entry.is_task ? "task" : "view"
      posts = entry.depends_on.includes?(:posts) ? "  ✓  " : "     "
      yamls = entry.depends_on.includes?(:yamls) ? "  ✓  " : "     "
      exifs = entry.depends_on.includes?(:exifs) ? "  ✓  " : "     "
      io.puts "%-32s | %s | %3d | %s | %s | %s |" % [
        entry.name[0, 32], type, entry.priority, posts, yamls, exifs
      ]
    end
  end

  def to_markdown : String
    String.build do |io|
      io.puts "# View Registry"
      io.puts ""
      io.puts "## Tasks (data preparation)"
      io.puts ""
      io.puts "| Name | Depends On | Priority |"
      io.puts "|------|------------|----------|"
      tasks.sort_by(&.priority).each do |t|
        io.puts "| #{t.name} | #{t.depends_on.join(", ")} | #{t.priority} |"
      end
      io.puts ""
      io.puts "## Views (render output)"
      io.puts ""
      io.puts "| Name | Depends On | Priority |"
      io.puts "|------|------------|----------|"
      views.sort_by(&.priority).each do |v|
        io.puts "| #{v.name} | #{v.depends_on.join(", ")} | #{v.priority} |"
      end
    end
  end
end
