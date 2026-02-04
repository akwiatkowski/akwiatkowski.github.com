require "yaml"

# Loads asset bundle configuration and resolves bundle names to CSS/JS files.
#
# Usage:
#   loader = AssetBundleLoader.new("data/config/asset_bundles.yml")
#   assets = loader.resolve(["core", "leaflet"])
#   assets.css  # => ["/css/libs/bootstrap.min.css", ...]
#   assets.js   # => ["/js/libs/jquery.min.js", ...]
#
class AssetBundleLoader
  Log = ::Log.for(self)

  struct Bundle
    getter name : String
    getter css : Array(String)
    getter js : Array(String)
    getter integrity : Hash(String, String)

    def initialize(
      @name : String,
      @css : Array(String) = [] of String,
      @js : Array(String) = [] of String,
      @integrity : Hash(String, String) = {} of String => String
    )
    end
  end

  struct ResolvedAssets
    getter css : Array(String)
    getter js : Array(String)
    getter integrity : Hash(String, String)

    def initialize(
      @css : Array(String),
      @js : Array(String),
      @integrity : Hash(String, String)
    )
    end
  end

  struct PageAsset
    getter name : String
    getter css : Array(String)
    getter js : Array(String)

    def initialize(
      @name : String,
      @css : Array(String) = [] of String,
      @js : Array(String) = [] of String
    )
    end
  end

  getter bundles : Hash(String, Bundle)
  getter composites : Hash(String, Array(String))
  getter page_assets : Hash(String, PageAsset)

  def initialize(config_path : String)
    @bundles = {} of String => Bundle
    @composites = {} of String => Array(String)
    @page_assets = {} of String => PageAsset
    load_config(config_path)
  end

  # Resolve bundle names (handles composites) and return merged assets
  def resolve(bundle_names : Array(String)) : ResolvedAssets
    all_bundles = expand_composites(bundle_names)
    merge_assets(all_bundles)
  end

  # Resolve page asset symbols to CSS paths
  def resolve_page_css(symbols : Array(String)) : Array(String)
    css = [] of String
    symbols.each do |symbol|
      if asset = @page_assets[symbol]?
        css.concat(asset.css)
      else
        Log.warn { "Unknown page asset: #{symbol}" }
      end
    end
    css.uniq
  end

  # Resolve page asset symbols to JS paths
  def resolve_page_js(symbols : Array(String)) : Array(String)
    js = [] of String
    symbols.each do |symbol|
      if asset = @page_assets[symbol]?
        js.concat(asset.js)
      else
        Log.warn { "Unknown page asset: #{symbol}" }
      end
    end
    js.uniq
  end

  private def load_config(config_path : String)
    unless File.exists?(config_path)
      Log.error { "Asset bundle config not found: #{config_path}" }
      return
    end

    yaml = YAML.parse(File.read(config_path))

    # Load bundles
    if bundles_yaml = yaml["bundles"]?
      bundles_yaml.as_h.each do |name, config|
        css = extract_string_array(config, "css")
        js = extract_string_array(config, "js")
        integrity = extract_string_hash(config, "integrity")

        @bundles[name.as_s] = Bundle.new(
          name: name.as_s,
          css: css,
          js: js,
          integrity: integrity
        )
      end
    end

    # Load composites
    if composites_yaml = yaml["composites"]?
      composites_yaml.as_h.each do |name, config|
        if includes = config["includes"]?
          @composites[name.as_s] = includes.as_a.map(&.as_s)
        end
      end
    end

    # Load page assets
    if page_assets_yaml = yaml["page-assets"]?
      page_assets_yaml.as_h.each do |name, config|
        css = extract_string_array(config, "css")
        js = extract_string_array(config, "js")

        @page_assets[name.as_s] = PageAsset.new(
          name: name.as_s,
          css: css,
          js: js
        )
      end
    end

    Log.info { "Loaded #{@bundles.size} bundles, #{@composites.size} composites, #{@page_assets.size} page assets" }
  end

  private def extract_string_array(yaml : YAML::Any, key : String) : Array(String)
    if arr = yaml[key]?
      arr.as_a.map(&.as_s)
    else
      [] of String
    end
  end

  private def extract_string_hash(yaml : YAML::Any, key : String) : Hash(String, String)
    result = {} of String => String
    if hash = yaml[key]?
      hash.as_h.each do |k, v|
        result[k.as_s] = v.as_s
      end
    end
    result
  end

  private def expand_composites(names : Array(String)) : Array(String)
    result = [] of String
    names.each do |name|
      if composite = @composites[name]?
        result.concat(expand_composites(composite))
      else
        result << name
      end
    end
    result.uniq
  end

  private def merge_assets(bundle_names : Array(String)) : ResolvedAssets
    css = [] of String
    js = [] of String
    integrity = {} of String => String

    bundle_names.each do |name|
      if bundle = @bundles[name]?
        css.concat(bundle.css)
        js.concat(bundle.js)
        integrity.merge!(bundle.integrity)
      else
        Log.warn { "Unknown bundle: #{name}" }
      end
    end

    ResolvedAssets.new(css.uniq, js.uniq, integrity)
  end
end
