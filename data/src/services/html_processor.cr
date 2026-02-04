require "./html_validators/all"

# Processes HTML output by removing comments and running validation.
#
# Usage:
#   processor = HtmlProcessor.new(validate: true)
#   result = processor.process(html, url)
#   result.html       # cleaned HTML
#   result.valid?     # true if no errors
#   result.errors     # Array(ValidationError)
#   result.warnings   # Array(ValidationWarning)
#
class HtmlProcessor
  Log = ::Log.for(self)

  struct ProcessResult
    getter html : String
    getter errors : Array(HtmlValidators::ValidationError)
    getter warnings : Array(HtmlValidators::ValidationWarning)

    def initialize(
      @html : String,
      @errors : Array(HtmlValidators::ValidationError),
      @warnings : Array(HtmlValidators::ValidationWarning)
    )
    end

    def valid?
      errors.empty?
    end
  end

  @validators : Array(HtmlValidators::Base)

  def initialize(@validate : Bool = true)
    @validators = [] of HtmlValidators::Base
    setup_validators if @validate
  end

  def process(html : String, url : String) : ProcessResult
    # Remove HTML comments (keep IE conditionals)
    cleaned = remove_comments(html)

    # Validate
    errors = [] of HtmlValidators::ValidationError
    warnings = [] of HtmlValidators::ValidationWarning

    if @validate
      @validators.each do |validator|
        result = validator.validate(cleaned, url)
        errors.concat(result.errors)
        warnings.concat(result.warnings)
      end
    end

    ProcessResult.new(cleaned, errors, warnings)
  end

  # Process without validation (for speed)
  def clean_only(html : String) : String
    remove_comments(html)
  end

  private def remove_comments(html : String) : String
    # Remove <!-- ... --> but keep <!--[if ... ]> IE conditionals
    html.gsub(/<!--(?!\[if).*?-->/m, "")
  end

  private def setup_validators
    @validators << HtmlValidators::MissingTitleValidator.new
    @validators << HtmlValidators::EmptyTitleValidator.new
    @validators << HtmlValidators::DuplicateIdValidator.new
    @validators << HtmlValidators::UnprocessedPlaceholderValidator.new
    @validators << HtmlValidators::MissingAltValidator.new
    @validators << HtmlValidators::InvalidHrefValidator.new
    @validators << HtmlValidators::MissingLangValidator.new
    @validators << HtmlValidators::MissingAssetsValidator.new
  end
end
