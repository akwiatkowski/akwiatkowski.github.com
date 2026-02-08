# Validates that HTML pages include required CSS and JS assets
#
# This validator catches cases where:
# - Asset bundle system fails to load config
# - Views don't include AssetAware module
# - Template rendering breaks asset inclusion
#
module HtmlValidators
  class MissingAssetsValidator < Base
    # Minimum expected assets for any HTML page
    REQUIRED_CSS_PATTERN = /<link[^>]+rel=["']stylesheet["'][^>]+href=/i
    REQUIRED_JS_PATTERN  = /<script[^>]+src=/i

    # Assets that should NOT be present (removed in Phase 14)
    FORBIDDEN_ASSETS = [
      "babel.min.js",
      "babel.js",
    ]

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      # Skip non-HTML content (feeds, JSON, etc.) and redirect stubs
      return ValidationResult.new(errors, warnings) unless html_page?(html)
      return ValidationResult.new(errors, warnings) if redirect_page?(html)

      # Check for any CSS
      unless html.match(REQUIRED_CSS_PATTERN)
        errors << ValidationError.new(url, "No CSS stylesheets found - asset bundle system may have failed")
      end

      # Check for any JS (warning only - some pages are intentionally JS-free)
      unless html.match(REQUIRED_JS_PATTERN)
        warnings << ValidationWarning.new(url, "No JavaScript files found")
      end

      # Check for forbidden assets (Babel should be removed)
      FORBIDDEN_ASSETS.each do |forbidden|
        if html.includes?(forbidden)
          warnings << ValidationWarning.new(url, "Found forbidden asset '#{forbidden}' - should have been removed in Phase 14")
        end
      end

      ValidationResult.new(errors, warnings)
    end

    private def html_page?(html : String) : Bool
      html.includes?("<!DOCTYPE html") || html.includes?("<html")
    end

    private def redirect_page?(html : String) : Bool
      html.includes?("window.location.replace")
    end
  end
end
