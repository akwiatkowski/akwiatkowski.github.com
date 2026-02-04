# Base module for HTML validators
module HtmlValidators
  struct ValidationError
    getter url : String
    getter message : String
    getter line : Int32?

    def initialize(@url : String, @message : String, @line : Int32? = nil)
    end

    def to_s
      if line
        "#{url}:#{line}: #{message}"
      else
        "#{url}: #{message}"
      end
    end
  end

  struct ValidationWarning
    getter url : String
    getter message : String
    getter line : Int32?

    def initialize(@url : String, @message : String, @line : Int32? = nil)
    end

    def to_s
      if line
        "#{url}:#{line}: #{message}"
      else
        "#{url}: #{message}"
      end
    end
  end

  struct ValidationResult
    getter errors : Array(ValidationError)
    getter warnings : Array(ValidationWarning)

    def initialize(
      @errors : Array(ValidationError) = [] of ValidationError,
      @warnings : Array(ValidationWarning) = [] of ValidationWarning
    )
    end

    def valid?
      errors.empty?
    end
  end

  # Base class for HTML validators
  abstract class Base
    abstract def validate(html : String, url : String) : ValidationResult
  end
end
