# MockRenderContext for testing views without a full Blog instance
#
# Usage in tests:
#   ctx = MockRenderContext.new
#   ctx.mock_site_title = "Test Site"
#   ctx.mock_posts = [create_test_post]
#
class MockRenderContext
  # Mock data storage
  property mock_site_title : String = "Test Site"
  property mock_site_url : String = "https://test.example.com"
  property mock_site_desc : String = "Test site description"
  property mock_posts : Array(MockPost) = [] of MockPost
  property mock_config : Hash(String, String) = {} of String => String
  property mock_asset_bundle_loader : AssetBundleLoader? = nil

  def initialize
  end

  def initialize(with_asset_loader : Bool)
    if with_asset_loader
      config_path = "data/config/asset_bundles.yml"
      if File.exists?(config_path)
        @mock_asset_bundle_loader = AssetBundleLoader.new(config_path)
      end
    end
  end

  # ============================================
  # RenderContext interface implementation
  # ============================================

  def site_title : String
    @mock_site_title
  end

  def site_url : String
    @mock_site_url
  end

  def site_desc : String
    @mock_site_desc
  end

  def title_for_page(name : String) : String
    @mock_config["#{name}.title"]? || ""
  end

  def subtitle_for_page(name : String) : String
    @mock_config["#{name}.subtitle"]? || ""
  end

  def background_for_page(name : String) : String
    @mock_config["#{name}.backgrounds"]? || ""
  end

  def posts
    @mock_posts
  end

  def published_posts
    @mock_posts.select(&.ready?)
  end

  def output_path : String
    "/tmp/test_output"
  end

  # Mock output_buffer
  def output_buffer
    @output_buffer ||= MockHtmlBuffer.new
  end

  def logger
    nil
  end

  # Asset bundle loader for testing asset-aware views
  def asset_bundle_loader : AssetBundleLoader?
    @mock_asset_bundle_loader
  end

  # ============================================
  # Helpers
  # ============================================

  def posts_for(entity) : Array(MockPost)
    [] of MockPost
  end

  def post_count_for(entity) : Int32
    0
  end

  # ============================================
  # Test setup helpers
  # ============================================

  def add_config(key : String, value : String)
    @mock_config[key] = value
  end

  def add_post(post : MockPost)
    @mock_posts << post
  end
end
