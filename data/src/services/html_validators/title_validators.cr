require "./base"

module HtmlValidators
  # Validates that <title> tag exists
  class MissingTitleValidator < Base
    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      unless html.includes?("<title>") || html.includes?("<title ")
        errors << ValidationError.new(url, "Missing <title> tag")
      end

      ValidationResult.new(errors, warnings)
    end
  end

  # Validates that <title> tag is not empty
  class EmptyTitleValidator < Base
    EMPTY_TITLE_REGEX = /<title>\s*<\/title>/i

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      if html.matches?(EMPTY_TITLE_REGEX)
        errors << ValidationError.new(url, "Empty <title> tag")
      end

      # Also check for title with only whitespace/dash
      if match = html.match(/<title>([^<]*)<\/title>/i)
        title_content = match[1].strip
        if title_content.empty? || title_content == "-"
          errors << ValidationError.new(url, "Invalid <title> content: '#{title_content}'")
        end
      end

      ValidationResult.new(errors, warnings)
    end
  end
end
