module StaticView
  class JsBicyclePlannerView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url : String)
    end

    # integrate but it require some html-head loading magic
    # def content
    #   data = Hash(String, String).new
    #   return load_html("map/bicycle_planner", data)
    # end

    def output
      full_html
    end

    def full_html
      data = Hash(String, String).new
      return load_html("map/bicycle_planner.full", data)
    end
  end
end
