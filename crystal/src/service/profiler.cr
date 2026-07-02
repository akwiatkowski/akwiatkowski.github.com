annotation Profile; end

class Profiler
  Log = ::Log.for(self)

  record Entry, category : String, name : String, duration_ms : Float64

  @@enabled : Bool = true
  @@entries : Array(Entry) = [] of Entry

  def self.enabled=(value : Bool)
    @@enabled = value
  end

  def self.enabled? : Bool
    @@enabled
  end

  def self.reset
    @@entries.clear
  end

  def self.record(category : String, name : String, duration_ms : Float64)
    @@entries << Entry.new(category: category, name: name, duration_ms: duration_ms)
  end

  # For dynamic names (coordinator entries, cross-object calls)
  def self.measure(category : String, name : String, &)
    unless @@enabled
      return yield
    end
    start = Time.instant
    result = yield
    elapsed = (Time.instant - start).total_milliseconds
    @@entries << Entry.new(category: category, name: name, duration_ms: elapsed)
    result
  end

  def self.summary
    return unless @@enabled
    return if @@entries.empty?
    total_ms = @@entries.sum(&.duration_ms)

    Log.info { "─── Profiler Summary ───" }
    by_category = @@entries
      .group_by(&.category)
      .map { |cat, entries| {cat, entries.sum(&.duration_ms), entries.size} }
      .sort_by { |_, ms, _| -ms }
    by_category.each do |cat, ms, count|
      pct = (ms / total_ms * 100).round(1)
      count_str = count > 1 ? " (#{count} items)" : ""
      Log.info { "  #{cat}: #{ms.round(1)}ms #{pct}%#{count_str}" }
    end
    Log.info { "  Total: #{total_ms.round(1)}ms" }

    top = @@entries.sort_by(&.duration_ms).reverse.first(10)
    Log.info { "─── Top 10 Slowest ───" }
    top.each do |e|
      Log.info { "  #{e.duration_ms.round(1)}ms - #{e.category}: #{e.name}" }
    end
    Log.info { "───────────────────────" }
  end
end
