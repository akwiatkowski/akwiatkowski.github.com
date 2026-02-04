# Module for views to declare which asset bundles they need.
#
# Views inherit bundles from their parent class by default.
# Override methods to customize:
#
#   def asset_bundles : Array(String)
#     ["core"]  # Base bundles (override completely)
#   end
#
#   def additional_bundles : Array(String)
#     ["leaflet"]  # Add to parent's bundles
#   end
#
#   def excluded_bundles : Array(String)
#     ["gallery-css"]  # Remove from inherited bundles
#   end
#
#   def page_js : String?
#     "/js/self/my_page.js"  # Optional page-specific JS
#   end
#
module AssetAware
  # Override to declare base asset bundles.
  # Default is "core" which includes Bootstrap, FontAwesome, and nav.
  def asset_bundles : Array(String)
    ["core"]
  end

  # Override to ADD bundles to parent's list
  def additional_bundles : Array(String)
    [] of String
  end

  # Override to REMOVE specific bundles from inheritance
  def excluded_bundles : Array(String)
    [] of String
  end

  # Optional page-specific JS file (vanilla JS or transpiled JSX)
  def page_js : String?
    nil
  end

  # Compute final bundle list with inheritance
  def resolved_bundles : Array(String)
    base = asset_bundles.dup
    base.concat(additional_bundles)
    base.reject! { |b| excluded_bundles.includes?(b) }
    base.uniq
  end

  # Generate <head> asset tags with cache busting
  # Accepts RenderContext or MockRenderContext (duck typing for testability)
  def assets_html(ctx) : String
    loader = ctx.asset_bundle_loader
    return "" unless loader

    assets = loader.resolve(resolved_bundles)
    output_path = ctx.output_path

    String.build do |s|
      # CSS
      assets.css.each do |path|
        cache_param = cache_param_for(path, output_path)
        integrity_attr = assets.integrity[path]? ? " integrity=\"#{assets.integrity[path]}\" crossorigin=\"anonymous\"" : ""
        s << "    <link rel=\"stylesheet\" href=\"#{path}?v=#{cache_param}\"#{integrity_attr}>\n"
      end

      # JS
      assets.js.each do |path|
        cache_param = cache_param_for(path, output_path)
        integrity_attr = assets.integrity[path]? ? " integrity=\"#{assets.integrity[path]}\" crossorigin=\"anonymous\"" : ""
        s << "    <script src=\"#{path}?v=#{cache_param}\"#{integrity_attr}></script>\n"
      end

      # Page-specific JS
      if js = page_js
        cache_param = cache_param_for(js, output_path)
        s << "    <script src=\"#{js}?v=#{cache_param}\"></script>\n"
      end
    end
  end

  private def cache_param_for(path : String, output_path : String) : String
    full_path = File.join(output_path, path)
    if File.exists?(full_path)
      File.info(full_path).modification_time.to_unix.to_s
    else
      Time.utc.to_unix.to_s
    end
  end
end
