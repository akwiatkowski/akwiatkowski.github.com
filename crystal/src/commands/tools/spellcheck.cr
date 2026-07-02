require "http/client"
require "json"
require "../base"

class Commands::Tools::Spellcheck
  Log = ::Log.for(self)

  LANGUAGETOOL_HOST = "localhost"
  LANGUAGETOOL_PORT = 8081
  CHECK_ENDPOINT    = "/v2/check"
  LANGUAGE          = "pl"
  CONNECT_TIMEOUT   =  2 # seconds
  READ_TIMEOUT      = 30 # seconds

  # Rules that fire too often on blog post content (markdown artifacts, proper nouns, etc.)
  DEFAULT_DISABLED_RULES = [
    "WHITESPACE_RULE",
    "COMMA_PARENTHESIS_WHITESPACE",
    "BRAK_SPACJI_NAWIAS", # triggered by markdown reference link syntax ][
  ]

  # Markdown patterns to strip as markup
  HEADING_RE      = /^(\#{1,6})\s+/m
  CODE_INLINE_RE  = /`[^`]+`/
  LINK_INLINE_RE  = /\[([^\]]*)\]\([^)]+\)/
  LINK_REF_RE     = /\[([^\]]*)\]\[([^\]]*)\]/
  LINK_DEF_RE     = /^\[([^\]]+)\]:\s+\S[^\n]*/m
  IMAGE_INLINE_RE = /!\[([^\]]*)\]\([^)]+\)/
  IMAGE_REF_RE    = /!\[([^\]]*)\]\[([^\]]*)\]/
  FUNCTION_RE     = /\{%[^%]*%\}/

  struct Match
    getter file : String
    getter line : Int32
    getter column : Int32
    getter rule_id : String
    getter message : String
    getter context_text : String
    getter replacements : Array(String)

    def initialize(@file, @line, @column, @rule_id, @message, @context_text, @replacements)
    end
  end

  def initialize(
    @env : String = "full",
    @slug_filter : String? = nil,
    @disabled_rules : Array(String) = DEFAULT_DISABLED_RULES,
    @verbose : Bool = false,
  )
  end

  def run
    unless languagetool_available?
      Log.warn { "LanguageTool not available at #{LANGUAGETOOL_HOST}:#{LANGUAGETOOL_PORT}. Skipping spellcheck." }
      Log.warn { "Install: brew install languagetool && brew services start languagetool" }
      return
    end

    posts_path = "env/#{@env}/data/posts"
    unless Dir.exists?(posts_path)
      Log.error { "Posts directory not found: #{posts_path}" }
      return
    end

    files = find_post_files(posts_path)
    Log.info { "Checking #{files.size} post files..." }

    total_matches = 0
    files_with_issues = 0

    files.each do |file|
      matches = check_file(file)
      next if matches.empty?

      files_with_issues += 1
      total_matches += matches.size

      matches.each do |m|
        replacements_str = m.replacements.empty? ? "" : " -> #{m.replacements.first(3).join(", ")}"
        puts "#{m.file}:#{m.line}:#{m.column}: #{m.rule_id} - #{m.message}#{replacements_str}"
        puts "  #{m.context_text}" if @verbose
      end
    end

    puts ""
    if total_matches == 0
      puts "No issues found in #{files.size} files."
    else
      puts "Found #{total_matches} issues in #{files_with_issues}/#{files.size} files."
    end
  end

  private def languagetool_available? : Bool
    client = HTTP::Client.new(LANGUAGETOOL_HOST, LANGUAGETOOL_PORT)
    client.connect_timeout = CONNECT_TIMEOUT.seconds
    client.read_timeout = CONNECT_TIMEOUT.seconds
    response = client.get("/v2/languages")
    response.status_code == 200
  rescue IO::Error | Socket::ConnectError | IO::TimeoutError
    false
  end

  private def find_post_files(posts_path : String) : Array(String)
    files = Dir.glob(File.join(posts_path, "**", "*.md")).sort
    if filter = @slug_filter
      files = files.select { |f| File.basename(f).includes?(filter) }
    end
    files
  end

  private def check_file(file_path : String) : Array(Match)
    raw = File.read(file_path)
    lines = raw.lines

    # Split YAML front matter from content
    content_start_line = find_content_start(lines)
    return [] of Match if content_start_line.nil?

    content_lines = lines[content_start_line..]
    content_text = content_lines.join("\n")

    # Strip markdown elements that confuse the checker
    clean_text = strip_markdown(content_text)

    return [] of Match if clean_text.strip.empty?

    # Send to LanguageTool
    api_matches = query_languagetool(clean_text)
    return [] of Match if api_matches.nil?

    # Map offsets back to file line:col
    map_matches(file_path, clean_text, content_start_line, api_matches)
  end

  # Find the line index where content starts (after second ---)
  private def find_content_start(lines : Array(String)) : Int32?
    separator_count = 0
    lines.each_with_index do |line, i|
      if line.matches?(/\A-{3,}\s*\z/)
        separator_count += 1
        return i + 1 if separator_count == 2
      end
    end
    nil
  end

  # Strip markdown syntax, replacing with spaces to preserve offsets
  private def strip_markdown(text : String) : String
    result = text

    # Remove code blocks entirely (replace with whitespace)
    result = result.gsub(/```[\s\S]*?```/) { |m| " " * m.size }

    # Remove inline code
    result = result.gsub(CODE_INLINE_RE) { |m| " " * m.size }

    # Remove function tags {% ... %}
    result = result.gsub(FUNCTION_RE) { |m| " " * m.size }

    # Remove link definition lines: [ref]: url
    result = result.gsub(LINK_DEF_RE) { |m| " " * m.size }

    # Remove images ![alt](url) and ![alt][ref] -> keep alt
    result = result.gsub(IMAGE_INLINE_RE) { |m| keep_group1(m, IMAGE_INLINE_RE) }
    result = result.gsub(IMAGE_REF_RE) { |m| keep_group1(m, IMAGE_REF_RE) }

    # Remove links [text](url) and [text][ref] -> keep text
    result = result.gsub(LINK_INLINE_RE) { |m| keep_group1(m, LINK_INLINE_RE) }
    result = result.gsub(LINK_REF_RE) { |m| keep_group1(m, LINK_REF_RE) }

    # Remove bold markers ** **
    result = result.gsub("**", "  ")

    # Remove heading markers (# at start of line)
    result = result.gsub(HEADING_RE) { |m| " " * m.size }

    result
  end

  # Keep capture group 1, pad rest with spaces to preserve offsets
  private def keep_group1(full_match : String, regex : Regex) : String
    if md = full_match.match(regex)
      text = md[1]
      padding = " " * (full_match.size - text.size)
      text + padding
    else
      " " * full_match.size
    end
  end

  private def query_languagetool(text : String) : JSON::Any?
    client = HTTP::Client.new(LANGUAGETOOL_HOST, LANGUAGETOOL_PORT)
    client.connect_timeout = CONNECT_TIMEOUT.seconds
    client.read_timeout = READ_TIMEOUT.seconds

    params = HTTP::Params.build do |p|
      p.add("language", LANGUAGE)
      p.add("text", text)
      p.add("disabledRules", @disabled_rules.join(",")) unless @disabled_rules.empty?
    end

    response = client.post(
      CHECK_ENDPOINT,
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      body: params,
    )

    if response.status_code == 200
      JSON.parse(response.body)
    else
      Log.warn { "LanguageTool returned #{response.status_code} for request" }
      nil
    end
  rescue ex : IO::Error | Socket::ConnectError | IO::TimeoutError
    Log.warn { "LanguageTool request failed: #{ex.message}" }
    nil
  end

  # Map character offsets from LanguageTool response to file line:column
  private def map_matches(file_path : String, text : String, content_start_line : Int32, response : JSON::Any) : Array(Match)
    matches = Array(Match).new
    api_matches = response["matches"]?.try(&.as_a) || return matches

    # Build offset-to-line mapping
    line_offsets = [0] # offset where each line starts
    text.each_char_with_index do |char, i|
      line_offsets << (i + 1) if char == '\n'
    end

    api_matches.each do |m|
      offset = m["offset"].as_i
      length = m["length"].as_i
      message = m["message"].as_s
      rule_id = m["rule"]["id"].as_s

      # Find which line this offset falls on
      content_line = 0
      line_offsets.each_with_index do |lo, i|
        if lo <= offset
          content_line = i
        else
          break
        end
      end

      column = offset - line_offsets[content_line] + 1
      file_line = content_line + content_start_line + 1 # 1-indexed

      context_text = m["context"]?.try(&.["text"]?.try(&.as_s)) || ""
      replacements = m["replacements"]?.try(&.as_a.first(5).map(&.["value"].as_s)) || [] of String

      matches << Match.new(
        file: file_path,
        line: file_line,
        column: column,
        rule_id: rule_id,
        message: message,
        context_text: context_text,
        replacements: replacements,
      )
    end

    matches
  end
end
