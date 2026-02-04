# OutputHistory tracks changes to rendered outputs across render sessions.
#
# Purpose: Detect when small code changes cause unexpected large output changes.
#
# Storage structure:
#   env/<env>/history/
#   └── <target>/                     # Target subdirectory
#       ├── index.html                # Summary page (easy to find at root)
#       └── pages/                    # All page histories in subdirectory
#           └── tag__najnowsze.html/  # Directory per output (flattened path)
#               ├── 2026-02-03__14-30     # Version 1 (oldest)
#               ├── 2026-02-03__14-35     # Version 2
#               ├── 2026-02-03__14-40     # Version 3 (newest)
#               └── 2026-02-03__14-40.diff # Diff: v2 → v3
#
class OutputHistory
  Log = ::Log.for(self)

  MAX_SIZE     = 500_000 # 500KB
  MAX_VERSIONS =       3

  # Track files changed in this session for index.html
  @changed_files : Array(NamedTuple(url: String, diff_path: String?, timestamp: String))
  @history_path : String
  @pages_path : String

  def initialize(@env : String = "dev", @target : String = "local")
    @history_path = File.join("env", @env, "history", @target)
    @pages_path = File.join(@history_path, "pages")
    @changed_files = [] of NamedTuple(url: String, diff_path: String?, timestamp: String)
    ensure_history_dir
  end

  # Check if a file should be tracked in history
  def trackable?(url : String, content : String) : Bool
    return false if content.bytesize > MAX_SIZE
    return false if url.ends_with?(".json")
    return false if binary_content?(content)

    # Only track HTML and SVG
    url.ends_with?(".html") || url.ends_with?(".svg")
  end

  # Track a file change - save new version and generate diff
  def track(url : String, old_content : String, new_content : String)
    dir_path = url_to_dir_path(url)
    ensure_dir(dir_path)

    timestamp = Time.local.to_s("%Y-%m-%d__%H-%M")
    version_path = File.join(dir_path, timestamp)

    # Find previous version for diff
    previous_version = latest_version(dir_path)

    # Save new version
    File.write(version_path, new_content)
    Log.debug { "Saved history version: #{version_path}" }

    # Generate diff if there was a previous version
    diff_path = nil
    if previous_version
      diff_path = "#{version_path}.diff"
      generate_diff(previous_version, version_path, diff_path)
    end

    # Cleanup old versions
    cleanup_old_versions(dir_path)

    # Track for index.html
    @changed_files << {url: url, diff_path: diff_path, timestamp: timestamp}
  end

  # Generate index.html summary at end of render
  def generate_index_html
    return if @changed_files.empty?

    index_path = File.join(@history_path, "index.html")
    render_time = Time.local.to_s("%Y-%m-%d %H:%M:%S")

    html = String.build do |s|
      s << "<!DOCTYPE html>\n"
      s << "<html><head>\n"
      s << "<meta charset=\"utf-8\">\n"
      s << "<title>Output History - #{render_time}</title>\n"
      s << "<style>\n"
      s << css_styles
      s << "</style>\n"
      s << "</head><body>\n"
      s << "<h1>Output History</h1>\n"
      s << "<p class=\"timestamp\">Render: #{render_time}</p>\n"
      s << "<p class=\"summary\">#{@changed_files.size} file(s) changed</p>\n"
      s << "<ul class=\"file-list\">\n"

      @changed_files.each do |file|
        s << "<li>\n"
        s << "<span class=\"url\">#{file[:url]}</span>\n"
        s << "<span class=\"time\">#{file[:timestamp]}</span>\n"

        if file[:diff_path] && File.exists?(file[:diff_path].not_nil!)
          diff_content = File.read(file[:diff_path].not_nil!)
          s << "<details>\n"
          s << "<summary>Show diff (#{diff_content.lines.size} lines)</summary>\n"
          s << "<pre class=\"diff\">#{format_diff(diff_content)}</pre>\n"
          s << "</details>\n"
        else
          s << "<span class=\"new-file\">(new file)</span>\n"
        end

        s << "</li>\n"
      end

      s << "</ul>\n"
      s << "</body></html>\n"
    end

    File.write(index_path, html)
    Log.info { "Generated history index: #{index_path} (#{@changed_files.size} files)" }
  end

  # Get count of changed files this session
  def changed_count : Int32
    @changed_files.size
  end

  # Print summary to console at end of render
  def print_summary
    if @changed_files.empty?
      Log.info { "No output changes detected" }
      return
    end

    # Count files with diffs vs new files
    with_diff = @changed_files.count { |f| f[:diff_path] && File.exists?(f[:diff_path].not_nil!) }
    new_files = @changed_files.size - with_diff

    # Build summary
    Log.info { "─" * 50 }
    Log.info { "Output History: #{@changed_files.size} file(s) changed" }

    if new_files > 0
      Log.info { "  New files: #{new_files}" }
    end
    if with_diff > 0
      Log.info { "  Modified:  #{with_diff}" }
    end

    # For small changes, show file list
    if @changed_files.size <= 10
      @changed_files.each do |file|
        marker = file[:diff_path] ? "~" : "+"
        Log.info { "  #{marker} #{file[:url]}" }
      end
    else
      # For large changes, show first 5 and count
      @changed_files.first(5).each do |file|
        marker = file[:diff_path] ? "~" : "+"
        Log.info { "  #{marker} #{file[:url]}" }
      end
      Log.info { "  ... and #{@changed_files.size - 5} more" }
    end

    index_path = File.join(@history_path, "index.html")
    Log.info { "  Details: #{index_path}" }
    Log.info { "─" * 50 }
  end

  private def ensure_history_dir
    Dir.mkdir_p(@history_path) unless Dir.exists?(@history_path)
    Dir.mkdir_p(@pages_path) unless Dir.exists?(@pages_path)
  end

  private def ensure_dir(path : String)
    Dir.mkdir_p(path) unless Dir.exists?(path)
  end

  private def url_to_dir_path(url : String) : String
    # Flatten path: /tag/najnowsze.html -> tag__najnowsze.html
    flattened = url.lstrip('/').gsub('/', "__")
    File.join(@pages_path, flattened)
  end

  private def binary_content?(content : String) : Bool
    # Check for null bytes or high ratio of non-printable characters
    return true if content.includes?('\0')

    # Sample first 1000 bytes
    sample = content[0, [content.size, 1000].min]
    non_printable = sample.count { |c| c < ' ' && c != '\n' && c != '\r' && c != '\t' }

    non_printable.to_f / sample.size > 0.1
  end

  private def latest_version(dir_path : String) : String?
    return nil unless Dir.exists?(dir_path)

    versions = Dir.children(dir_path)
      .reject { |f| f.ends_with?(".diff") }
      .sort

    versions.empty? ? nil : File.join(dir_path, versions.last)
  end

  private def generate_diff(old_path : String, new_path : String, diff_path : String)
    # Use system diff -u for unified diff format
    result = Process.run(
      "diff",
      ["-u", old_path, new_path],
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Close
    ) do |process|
      output = process.output.gets_to_end
      File.write(diff_path, output)
    end

    Log.debug { "Generated diff: #{diff_path}" }
  rescue ex
    Log.warn { "Failed to generate diff: #{ex.message}" }
  end

  private def cleanup_old_versions(dir_path : String)
    return unless Dir.exists?(dir_path)

    # Get all version files (not .diff files)
    versions = Dir.children(dir_path)
      .reject { |f| f.ends_with?(".diff") }
      .sort

    # Delete oldest versions if more than MAX_VERSIONS
    while versions.size > MAX_VERSIONS
      oldest = versions.shift
      oldest_path = File.join(dir_path, oldest)
      oldest_diff = "#{oldest_path}.diff"

      File.delete(oldest_path) if File.exists?(oldest_path)
      File.delete(oldest_diff) if File.exists?(oldest_diff)

      Log.debug { "Deleted old version: #{oldest_path}" }
    end
  end

  private def escape_html(text : String) : String
    text
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
  end

  private def format_diff(diff_content : String) : String
    diff_content.lines.map do |line|
      escaped = escape_html(line)
      case
      when line.starts_with?("+++"), line.starts_with?("---")
        "<span class=\"diff-file\">#{escaped}</span>"
      when line.starts_with?("@@")
        "<span class=\"diff-hunk\">#{escaped}</span>"
      when line.starts_with?("+")
        "<span class=\"diff-add\">#{escaped}</span>"
      when line.starts_with?("-")
        "<span class=\"diff-del\">#{escaped}</span>"
      else
        escaped
      end
    end.join("\n")
  end

  private def css_styles : String
    <<-CSS
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
        background: #1a1a2e;
        color: #a8b2c3;
      }
      h1 { color: #c9b8e8; }
      .timestamp { color: #7a8599; font-size: 14px; }
      .summary { font-weight: bold; color: #8bc6d4; }
      .file-list { list-style: none; padding: 0; }
      .file-list li {
        background: #252540;
        margin: 10px 0;
        padding: 15px;
        border-radius: 5px;
        border: 1px solid #3a3a5c;
      }
      .url { font-family: monospace; font-weight: bold; color: #d4bfff; }
      .time { color: #7a8599; margin-left: 10px; font-size: 12px; }
      .new-file { color: #a8d8a8; margin-left: 10px; }
      details { margin-top: 10px; }
      summary {
        cursor: pointer;
        color: #8bc6d4;
        font-size: 14px;
      }
      summary:hover { color: #a8dce8; }
      .diff {
        background: #16162a;
        color: #a8b2c3;
        padding: 15px;
        border-radius: 5px;
        overflow-x: auto;
        font-size: 12px;
        line-height: 1.5;
        border: 1px solid #2a2a4a;
      }
      .diff-file { color: #c9b8e8; font-weight: bold; }
      .diff-hunk { color: #8bc6d4; }
      .diff-add { color: #a8d8a8; }
      .diff-del { color: #e8a8a8; }
    CSS
  end
end
