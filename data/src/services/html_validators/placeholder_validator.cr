require "./base"

module HtmlValidators
  # Validates that no unprocessed template placeholders remain ({{...}})
  class UnprocessedPlaceholderValidator < Base
    # Matches {{anything}} but not {{{ or }}} (some JS frameworks use those)
    PLACEHOLDER_REGEX = /\{\{(?!\{)([^}]+)\}\}(?!\})/

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      line_number = 0
      html.each_line do |line|
        line_number += 1

        # Skip lines inside <script> tags - React/JSX may use similar syntax
        next if in_script_context?(html, line_number)

        line.scan(PLACEHOLDER_REGEX).each do |match|
          placeholder = match[1]
          errors << ValidationError.new(
            url,
            "Unprocessed template placeholder: {{#{placeholder}}}",
            line_number
          )
        end
      end

      ValidationResult.new(errors, warnings)
    end

    private def in_script_context?(html : String, target_line : Int32) : Bool
      # Simple heuristic: check if we're between <script> and </script>
      # This is a basic check - a full parser would be more accurate
      in_script = false
      current_line = 0

      html.each_line do |line|
        current_line += 1

        if line.includes?("<script")
          in_script = true
        end

        return in_script if current_line == target_line

        if line.includes?("</script>")
          in_script = false
        end
      end

      false
    end
  end
end
