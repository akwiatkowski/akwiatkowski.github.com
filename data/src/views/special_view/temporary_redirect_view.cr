module SpecialView
  # Temporary redirect view (302-style)
  # Uses JavaScript redirect instead of meta refresh
  # For URLs that may change again in the future
  class TemporaryRedirectView < BaseView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @old_url : String,
      @new_url : String,
    )
      @url = @old_url
      super(context: context, url: @url)
    end

    getter :old_url, :new_url, :url

    def output
      return to_html
    end

    def add_to_sitemap?
      false
    end

    def to_html
      data = Hash(String, String).new
      data["url.old"] = old_url
      data["url.new"] = new_url

      return load_html("302", data)
    end
  end
end
