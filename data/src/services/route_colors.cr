require "yaml"

# Loads route color config from data/config/route_colors.yml
# Used by Crystal SVG renderers and the JS generator
class RouteColors
  Log = ::Log.for(self)

  record Style, color_rgb : String, weight : Int32, opacity : Float64

  getter styles : Hash(String, Style)

  def initialize(config_path : String)
    @styles = Hash(String, Style).new
    load(File.join(config_path, "route_colors.yml"))
  end

  def color_rgb_for(route_type : String) : String?
    @styles[route_type]?.try(&.color_rgb)
  end

  def has_type?(route_type : String) : Bool
    @styles.has_key?(route_type)
  end

  def allowed_types : Array(String)
    @styles.keys
  end

  private def load(path : String)
    unless File.exists?(path)
      Log.error { "Route colors config not found: #{path}" }
      return
    end

    yaml = YAML.parse(File.read(path))
    yaml.as_h.each do |key, value|
      color = value["color"].as_s
      # Extract RGB values from "rgb(R, G, B)" format
      rgb = color.gsub(/rgb\(|\)|\s/, "")
      weight = value["weight"].as_i.to_i
      opacity = value["opacity"].as_f? || value["opacity"].as_i.to_f
      @styles[key.as_s] = Style.new(color_rgb: rgb, weight: weight, opacity: opacity)
    end

    Log.debug { "Loaded #{@styles.size} route color styles" }
  end
end
