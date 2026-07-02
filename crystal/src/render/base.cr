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

  alias EntryBlock = Proc(BuildContext, Nil)

  # ============================================
  # Priority Ranges (single source of truth)
  # ============================================
  # Tasks run before views. Lower priority = runs first.

  PRIORITY_GROUPS = [
    {range: 1..2, name: "Setup tasks", desc: "Dev render, copy assets", is_task: true},
    {range: 3..4, name: "EXIF tasks", desc: "Initialize EXIF data", is_task: true},
    {range: 5..9, name: "Cache tasks", desc: "Refresh caches", is_task: true},
    {range: 10..19, name: "Entity views", desc: "Towns, tags, voivodeships, lands", is_task: false},
    {range: 20..29, name: "Home views", desc: "Home, map, POIs", is_task: false},
    {range: 30..39, name: "Photo views", desc: "Galleries, photo maps", is_task: false},
    {range: 40..49, name: "Stats views", desc: "Summary, year reports, burnout", is_task: false},
    {range: 50..59, name: "Feed views", desc: "RSS, Atom, JSON, sitemap", is_task: false},
    {range: 60..69, name: "Index views", desc: "Entity indexes", is_task: false},
    {range: 90..99, name: "Static views", desc: "About, more, JS pages", is_task: false},
    {range: 100..199, name: "Debug views", desc: "Diagnostic pages", is_task: false},
  ]

  # Convenience constants for use in registrations
  module Priority
    SETUP  =   1
    EXIF   =   4
    CACHE  =   5
    ENTITY =  10
    HOME   =  20
    PHOTO  =  30
    STATS  =  40
    FEED   =  50
    INDEX  =  60
    STATIC =  90
    DEBUG  = 100
  end

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
    &block : BuildContext -> Nil
  ) : self
    @entries << Entry.new(name, depends_on, block, priority, is_task: false)
    self
  end

  # Register a task (prepares data, no output)
  def task(
    name : String,
    depends_on : Array(Symbol),
    priority : Int32 = 1,
    &block : BuildContext -> Nil
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
        entry.name[0, 32], type, entry.priority, posts, yamls, exifs,
      ]
    end
  end

  def to_markdown : String
    String.build do |io|
      io.puts "# View Registry"
      io.puts ""
      io.puts "*Auto-generated from ViewRegistry. Do not edit manually.*"
      io.puts ""

      # Summary
      io.puts "## Summary"
      io.puts ""
      io.puts "- **Tasks**: #{tasks.size}"
      io.puts "- **Views**: #{views.size}"
      io.puts "- **Total entries**: #{@entries.size}"
      io.puts ""

      # Dependency overview
      io.puts "## What runs when..."
      io.puts ""
      io.puts "| Trigger | Entries |"
      io.puts "|---------|---------|"
      io.puts "| `:posts` changed | #{names_depending_on(:posts).size} entries |"
      io.puts "| `:yamls` changed | #{names_depending_on(:yamls).size} entries |"
      io.puts "| `:exifs` changed | #{names_depending_on(:exifs).size} entries |"
      io.puts "| Always runs | #{@entries.count { |e| e.depends_on.empty? }} entries |"
      io.puts ""

      # Entries by category (using PRIORITY_GROUPS)
      io.puts "## Entries by Category"
      io.puts ""

      PRIORITY_GROUPS.each do |group|
        group_entries = @entries.select { |e| group[:range].includes?(e.priority) }.sort_by(&.priority)
        next if group_entries.empty?

        io.puts "### #{group[:name]} (priority #{group[:range]})"
        io.puts ""
        io.puts group[:desc]
        io.puts ""
        io.puts "| Priority | Name | Triggers |"
        io.puts "|----------|------|----------|"
        group_entries.each do |e|
          triggers = e.depends_on.empty? ? "always" : e.depends_on.join(", ")
          io.puts "| #{e.priority} | #{e.name} | #{triggers} |"
        end
        io.puts ""
      end

      # Full dependency matrix
      io.puts "## Dependency Matrix"
      io.puts ""
      io.puts "```"
      io.puts "Entry                            | Type | Pri | posts | yamls | exifs |"
      io.puts "---------------------------------|------|-----|-------|-------|-------|"
      @entries.sort_by(&.priority).each do |entry|
        type = entry.is_task ? "task" : "view"
        posts = entry.depends_on.includes?(:posts) ? "  ✓  " : "     "
        yamls = entry.depends_on.includes?(:yamls) ? "  ✓  " : "     "
        exifs = entry.depends_on.includes?(:exifs) ? "  ✓  " : "     "
        io.puts "%-32s | %s | %3d | %s | %s | %s |" % [
          entry.name[0, 32], type, entry.priority, posts, yamls, exifs,
        ]
      end
      io.puts "```"
      io.puts ""

      # Priority guide (generated from PRIORITY_GROUPS)
      io.puts "## Priority Guide"
      io.puts ""
      io.puts "| Range | Type | Description |"
      io.puts "|-------|------|-------------|"
      PRIORITY_GROUPS.each do |group|
        type_label = group[:is_task] ? "task" : "view"
        io.puts "| #{group[:range]} | #{group[:name]} | #{group[:desc]} |"
      end
    end
  end
end
