require "./base"

module HtmlValidators
  # Validates that no href="#" or empty hrefs exist
  class InvalidHrefValidator < Base
    EMPTY_HREF_REGEX = /href=["']\s*["']/i
    HASH_ONLY_HREF_REGEX = /href=["']#["']/

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      if html.matches?(EMPTY_HREF_REGEX)
        warnings << ValidationWarning.new(url, "Empty href attribute found")
      end

      # href="#" is often used as placeholder but should be avoided
      if html.matches?(HASH_ONLY_HREF_REGEX)
        warnings << ValidationWarning.new(url, "Placeholder href=\"#\" found - consider using button or valid link")
      end

      ValidationResult.new(errors, warnings)
    end
  end
end
