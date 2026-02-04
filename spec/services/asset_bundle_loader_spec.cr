require "../spec_helper"

describe AssetBundleLoader do
  config_path = "data/config/asset_bundles.yml"

  describe "#initialize" do
    it "loads bundles from config file" do
      loader = AssetBundleLoader.new(config_path)
      loader.bundles.size.should be > 0
    end

    it "loads composites from config file" do
      loader = AssetBundleLoader.new(config_path)
      loader.composites.size.should be > 0
    end
  end

  describe "#resolve" do
    it "resolves simple bundle to CSS and JS files" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["bootstrap-css"])
      assets.css.should contain "/css/libs/bootstrap.min.css"
      assets.js.should be_empty
    end

    it "resolves JS bundle" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["jquery"])
      assets.js.should contain "/js/libs/jquery.min.js"
    end

    it "resolves composite bundle" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["core"])
      assets.css.should contain "/css/libs/bootstrap.min.css"
      assets.js.should contain "/js/libs/bootstrap.bundle.min.js"
    end

    it "preserves integrity attributes" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["leaflet-css"])
      assets.integrity["/css/libs/leaflet.css"]?.should_not be_nil
    end

    it "deduplicates assets" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["bootstrap-css", "bootstrap-css"])
      assets.css.count("/css/libs/bootstrap.min.css").should eq 1
    end

    it "resolves multiple bundles" do
      loader = AssetBundleLoader.new(config_path)
      assets = loader.resolve(["core", "leaflet"])
      assets.css.should contain "/css/libs/bootstrap.min.css"
      assets.css.should contain "/css/libs/leaflet.css"
      assets.js.should contain "/js/libs/leaflet.js"
    end
  end
end
