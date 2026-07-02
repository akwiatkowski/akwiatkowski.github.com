require "yaml"

module SpecialView
  # Generates /js/self/route_colors.js from data/config/route_colors.yml
  # Sets window.ROUTE_STYLES for use by all map pages
  class RouteColorsJsGenerator < Tremolite::Views::AbstractView
    Log = ::Log.for(self)

    def initialize(
      context : RenderContext,
      @url : String = "/js/self/route_colors.js",
    )
      @context = context
    end

    getter :url

    def output
      generate_js
    end

    def add_to_sitemap?
      false
    end

    private def generate_js : String
      config_path = File.join(@context.config_path, "route_colors.yml")
      yaml = YAML.parse(File.read(config_path))

      lines = ["// Auto-generated from data/config/route_colors.yml", "window.ROUTE_STYLES = {"]

      yaml.as_h.each_with_index do |(key, value), idx|
        color = value["color"].as_s
        weight = value["weight"].as_i
        opacity = value["opacity"]
        comma = idx < yaml.as_h.size - 1 ? "," : ""
        lines << "  '#{key}': { color: '#{color}', weight: #{weight}, opacity: #{opacity} }#{comma}"
      end

      lines << "};"
      lines << ""
      lines << "window.ROUTE_TAG_PRIORITY = ['hike', 'bicycle', 'e-bike', 'canoe', 'car', 'ev', 'bus', 'train'];"
      lines << ""
      lines << "window.getRouteStyle = function(tags) {"
      lines << "  for (var i = 0; i < window.ROUTE_TAG_PRIORITY.length; i++) {"
      lines << "    if (tags && tags.indexOf(window.ROUTE_TAG_PRIORITY[i]) !== -1) return window.ROUTE_STYLES[window.ROUTE_TAG_PRIORITY[i]];"
      lines << "  }"
      lines << "  return window.ROUTE_STYLES.regular;"
      lines << "};"

      lines.join("\n")
    end
  end
end
