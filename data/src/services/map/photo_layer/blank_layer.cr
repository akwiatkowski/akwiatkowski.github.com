class Map::PhotoLayer::BlankLayer
  Log = ::Log.for(self)

  def initialize
  end

  def render_svg
    return String.build do |s|
      # no photo layer
    end
  end
end
