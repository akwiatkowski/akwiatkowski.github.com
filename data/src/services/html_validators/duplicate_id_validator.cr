require "./base"

module HtmlValidators
  # Validates that no duplicate id attributes exist
  class DuplicateIdValidator < Base
    ID_REGEX = /id=["']([^"']+)["']/i

    def validate(html : String, url : String) : ValidationResult
      errors = [] of ValidationError
      warnings = [] of ValidationWarning

      id_counts = Hash(String, Int32).new(0)

      html.scan(ID_REGEX).each do |match|
        id_value = match[1]
        id_counts[id_value] += 1
      end

      id_counts.each do |id, count|
        if count > 1
          errors << ValidationError.new(url, "Duplicate id='#{id}' found #{count} times")
        end
      end

      ValidationResult.new(errors, warnings)
    end
  end
end
