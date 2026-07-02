require "./spec_helper"

describe RenderContext do
  # Note: These tests require a real Blog instance
  # For unit tests without Blog, use MockRenderContext

  describe "with mock" do
    it "MockRenderContext provides site_title" do
      ctx = MockRenderContext.new
      ctx.mock_site_title = "My Test Site"

      ctx.site_title.should eq "My Test Site"
    end

    it "MockRenderContext provides site_url" do
      ctx = MockRenderContext.new
      ctx.mock_site_url = "https://example.com"

      ctx.site_url.should eq "https://example.com"
    end

    it "MockRenderContext provides page data access" do
      ctx = MockRenderContext.new
      ctx.add_config("home.title", "Welcome")

      ctx.title_for_page("home").should eq "Welcome"
    end

    it "MockRenderContext returns empty string for missing page data" do
      ctx = MockRenderContext.new

      ctx.title_for_page("nonexistent").should eq ""
    end

    it "MockRenderContext provides posts" do
      ctx = MockRenderContext.new
      post = MockPost.new(slug: "test-1", title: "First Post")
      ctx.add_post(post)

      ctx.posts.size.should eq 1
      ctx.posts.first.title.should eq "First Post"
    end

    it "MockRenderContext filters published posts" do
      ctx = MockRenderContext.new
      ctx.add_post(MockPost.new(slug: "ready", title: "Ready", ready: true))
      ctx.add_post(MockPost.new(slug: "draft", title: "Draft", ready: false))

      ctx.published_posts.size.should eq 1
      ctx.published_posts.first.slug.should eq "ready"
    end

    it "MockHtmlBuffer caches values" do
      ctx = MockRenderContext.new
      ctx.output_buffer.buffer["test_key"] = "cached_value"

      ctx.output_buffer.buffer["test_key"].should eq "cached_value"
    end
  end

  describe "MockPost" do
    it "has default values" do
      post = MockPost.new

      post.slug.should eq "test-post"
      post.title.should eq "Test Post Title"
      post.ready?.should be_true
      post.todo?.should be_false
    end

    it "can be customized" do
      post = MockPost.new(
        slug: "custom-slug",
        title: "Custom Title",
        ready: false
      )

      post.slug.should eq "custom-slug"
      post.title.should eq "Custom Title"
      post.ready?.should be_false
    end
  end
end
