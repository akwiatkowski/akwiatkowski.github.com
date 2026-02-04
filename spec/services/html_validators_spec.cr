require "../spec_helper"

describe HtmlValidators do
  describe HtmlValidators::MissingTitleValidator do
    it "detects missing title" do
      html = "<html><head></head><body></body></html>"
      validator = HtmlValidators::MissingTitleValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.size.should eq 1
      result.errors.first.message.should contain "Missing <title>"
    end

    it "passes with title present" do
      html = "<html><head><title>Hello</title></head><body></body></html>"
      validator = HtmlValidators::MissingTitleValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.should be_empty
    end
  end

  describe HtmlValidators::EmptyTitleValidator do
    it "detects empty title" do
      html = "<html><head><title></title></head><body></body></html>"
      validator = HtmlValidators::EmptyTitleValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.size.should be > 0
      result.errors.any? { |e| e.message.includes?("Invalid") || e.message.includes?("Empty") }.should be_true
    end

    it "detects title with only whitespace" do
      html = "<html><head><title>   </title></head><body></body></html>"
      validator = HtmlValidators::EmptyTitleValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.size.should be > 0
    end

    it "passes with valid title" do
      html = "<html><head><title>Hello World</title></head><body></body></html>"
      validator = HtmlValidators::EmptyTitleValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.should be_empty
    end
  end

  describe HtmlValidators::DuplicateIdValidator do
    it "detects duplicate ids" do
      html = "<div id=\"test\"></div><div id=\"test\"></div>"
      validator = HtmlValidators::DuplicateIdValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.size.should eq 1
      result.errors.first.message.should contain "Duplicate id='test'"
    end

    it "passes with unique ids" do
      html = "<div id=\"one\"></div><div id=\"two\"></div>"
      validator = HtmlValidators::DuplicateIdValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.should be_empty
    end
  end

  describe HtmlValidators::UnprocessedPlaceholderValidator do
    it "detects unprocessed placeholders" do
      html = "<html><body><p>Hello {{name}}</p></body></html>"
      validator = HtmlValidators::UnprocessedPlaceholderValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.size.should eq 1
      result.errors.first.message.should contain "{{name}}"
    end

    it "passes with no placeholders" do
      html = "<html><body><p>Hello World</p></body></html>"
      validator = HtmlValidators::UnprocessedPlaceholderValidator.new
      result = validator.validate(html, "/test.html")
      result.errors.should be_empty
    end
  end

  describe HtmlValidators::MissingAltValidator do
    it "warns on img without alt" do
      html = "<img src=\"/photo.jpg\">"
      validator = HtmlValidators::MissingAltValidator.new
      result = validator.validate(html, "/test.html")
      result.warnings.size.should eq 1
      result.warnings.first.message.should contain "Missing alt"
    end

    it "passes with alt attribute" do
      html = "<img src=\"/photo.jpg\" alt=\"A photo\">"
      validator = HtmlValidators::MissingAltValidator.new
      result = validator.validate(html, "/test.html")
      result.warnings.should be_empty
    end
  end

  describe HtmlValidators::MissingLangValidator do
    it "warns on html without lang" do
      html = "<html><head></head></html>"
      validator = HtmlValidators::MissingLangValidator.new
      result = validator.validate(html, "/test.html")
      result.warnings.size.should eq 1
    end

    it "passes with lang attribute" do
      html = "<html lang=\"pl\"><head></head></html>"
      validator = HtmlValidators::MissingLangValidator.new
      result = validator.validate(html, "/test.html")
      result.warnings.should be_empty
    end
  end
end
