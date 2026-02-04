require "../spec_helper"

# Test helper class that includes AssetAware
class TestAssetAwareView
  include AssetAware

  def initialize(
    @bundles : Array(String) = ["core"],
    @additional : Array(String) = [] of String,
    @excluded : Array(String) = [] of String,
    @css : Array(String) = [] of String,
    @js : String? = nil
  )
  end

  def asset_bundles : Array(String)
    @bundles
  end

  def additional_bundles : Array(String)
    @additional
  end

  def excluded_bundles : Array(String)
    @excluded
  end

  def page_css : Array(String)
    @css
  end

  def page_js : String?
    @js
  end
end

describe AssetAware do
  config_path = "data/config/asset_bundles.yml"

  describe "#resolved_bundles" do
    it "returns base bundles by default" do
      view = TestAssetAwareView.new
      view.resolved_bundles.should eq ["core"]
    end

    it "adds additional bundles" do
      view = TestAssetAwareView.new(additional: ["leaflet"])
      bundles = view.resolved_bundles
      bundles.should contain "core"
      bundles.should contain "leaflet"
    end

    it "removes excluded bundles" do
      view = TestAssetAwareView.new(bundles: ["core", "leaflet"], excluded: ["leaflet"])
      bundles = view.resolved_bundles
      bundles.should contain "core"
      bundles.should_not contain "leaflet"
    end

    it "deduplicates bundles" do
      view = TestAssetAwareView.new(bundles: ["core"], additional: ["core", "leaflet"])
      bundles = view.resolved_bundles
      bundles.count("core").should eq 1
    end
  end

  describe "#assets_html" do
    it "returns empty string when no loader available" do
      ctx = MockRenderContext.new
      view = TestAssetAwareView.new
      html = view.assets_html(ctx)
      html.should eq ""
    end

    it "generates CSS link tags with loader" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new
      html = view.assets_html(ctx)
      html.should contain "<link rel=\"stylesheet\""
      html.should contain "/css/libs/bootstrap.min.css"
    end

    it "generates JS script tags with loader" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new
      html = view.assets_html(ctx)
      html.should contain "<script src="
      html.should contain "/js/libs/jquery.min.js"
    end

    it "includes cache busting parameters" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new
      html = view.assets_html(ctx)
      html.should match /\?v=\d+/
    end

    it "includes integrity attributes when available" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(additional: ["leaflet"])
      html = view.assets_html(ctx)
      html.should contain "integrity="
      html.should contain "crossorigin="
    end

    it "includes nav_stats.js for core bundle" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new
      html = view.assets_html(ctx)
      html.should contain "/js/self/nav_stats.js"
    end

    it "does NOT include Babel" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(additional: ["react-runtime"])
      html = view.assets_html(ctx)
      html.should_not contain "babel"
    end

    it "includes page-specific CSS when set" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(css: ["gallery"])
      html = view.assets_html(ctx)
      html.should contain "/css/self/new_gallery.css"
      html.should contain "/css/self/coord_photo.css"
    end

    it "includes page-specific JS when set" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(js: "/js/self/custom.js")
      html = view.assets_html(ctx)
      html.should contain "/js/self/custom.js"
    end

    it "generates correct assets for leaflet bundle" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(additional: ["leaflet"])
      html = view.assets_html(ctx)
      html.should contain "/css/libs/leaflet.css"
      html.should contain "/js/libs/leaflet.js"
    end

    it "generates correct assets for react-runtime bundle" do
      ctx = MockRenderContext.new(with_asset_loader: true)
      view = TestAssetAwareView.new(additional: ["react-runtime"])
      html = view.assets_html(ctx)
      html.should contain "/js/libs/react.production.min.js"
      html.should contain "/js/libs/react-dom.production.min.js"
    end
  end
end
