require "./base"

module HtmlValidators
  # Validates that no unprocessed template placeholders remain ({{...}})
  class UnprocessedPlaceholderValidator < Base
    # Matches {{anything}} but not {{{ or }}} (some JS frameworks use those)
    PLACEHOLDER_REGEX = /\{\{(?!\{)([^}]+)\}\}(?!\})/

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      in_script = false
      line_number = 0

      html.each_line do |line|
        line_number += 1

        if line.includes?("<script")
          in_script = true
        end

        unless in_script
          line.scan(PLACEHOLDER_REGEX).each do |match|
            placeholder = match[1]
            errors << ValidationError.new(
              url,
              "Unprocessed template placeholder: {{#{placeholder}}}",
              line_number
            )
          end
        end

        if line.includes?("</script>")
          in_script = false
        end
      end

      ValidationResult.new(errors, warnings)
    end
  end
end
