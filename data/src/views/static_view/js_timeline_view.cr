module StaticView
  class JsTimelineView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
    end

    def content
      data = Hash(String, String).new
      return load_html("photos/timeline", data)
    end
  end
end
