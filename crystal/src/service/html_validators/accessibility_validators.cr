require "./base"

module HtmlValidators
  # Validates that <img> tags have alt attributes
  class MissingAltValidator < Base
    # Match <img ... > without alt attribute
    IMG_REGEX = /<img\s+[^>]*>/i

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      html.scan(IMG_REGEX).each do |match|
        img_tag = match[0]
        unless img_tag.includes?("alt=")
          # Extract src for better error message
          if src_match = img_tag.match(/src=["']([^"']+)["']/i)
            src = src_match[1]
            warnings << ValidationWarning.new(url, "Missing alt attribute on <img src=\"#{src}\">")
          else
            warnings << ValidationWarning.new(url, "Missing alt attribute on <img> tag")
          end
        end
      end

      ValidationResult.new(errors, warnings)
    end
  end

  # Validates that <html> tag has lang attribute
  class MissingLangValidator < Base
    HTML_REGEX = /<html[^>]*>/i

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      if match = html.match(HTML_REGEX)
        html_tag = match[0]
        unless html_tag.includes?("lang=")
          warnings << ValidationWarning.new(url, "Missing lang attribute on <html> tag")
        end
      end

      ValidationResult.new(errors, warnings)
    end
  end
end
