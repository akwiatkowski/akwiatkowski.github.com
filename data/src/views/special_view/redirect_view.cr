require "json"

module SpecialView
  class RedirectView < BaseView
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

    def to_html
      data = Hash(String, String).new
      data["url.old"] = old_url
      data["url.new"] = new_url

      return load_html("301", data)
    end
  end
end
