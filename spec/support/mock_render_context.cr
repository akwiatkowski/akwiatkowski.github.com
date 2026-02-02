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

  def initialize
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

  def [](key : String) : String
    @mock_config[key]? || ""
  end

  def []?(key : String) : String?
    @mock_config[key]?
  end

  def posts
    @mock_posts
  end

  def ready_posts
    @mock_posts.select(&.ready?)
  end

  def output_path : String
    "/tmp/test_output"
  end

  # Mock html_buffer
  def html_buffer
    @html_buffer ||= MockHtmlBuffer.new
  end

  def logger
    nil
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
