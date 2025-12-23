module StaticView
  class IdeasView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
    end

    def content
      data = Hash(String, String).new
      return load_html("ideas/ideas", data)
    end
  end
end
