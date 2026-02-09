require "../spec_helper"
require "file_utils"

describe PreloadedPostReferencedLinks do
  describe "#populate_referenced_links" do
    it "extracts reference links from markdown files" do
      # Create temp dir with a test markdown file
      tmp_dir = File.tempname("test_posts", "")
      Dir.mkdir_p(tmp_dir)

      File.write(File.join(tmp_dir, "2024-01-01-test.md"),
        "---\ntitle: Test\n---\n\nSome content with a [link][wiki].\n\n[wiki]: https://en.wikipedia.org\n[town]: https://example.com/town\n"
      )

      html_buffer = Tremolite::HtmlBuffer.new
      service = PreloadedPostReferencedLinks.new(
        html_buffer: html_buffer,
        posts_path: tmp_dir,
        posts_ext: "md"
      )

      service.populate_referenced_links

      # Verify links were extracted
      wiki_link = html_buffer.get_referenced_link("wiki")
      wiki_link.should_not be_nil
      wiki_link.not_nil![:url].should eq("https://en.wikipedia.org")
      wiki_link.not_nil![:post_slug].should eq("2024-01-01-test")

      town_link = html_buffer.get_referenced_link("town")
      town_link.should_not be_nil
      town_link.not_nil![:url].should eq("https://example.com/town")
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end

    it "handles empty directory" do
      tmp_dir = File.tempname("test_posts_empty", "")
      Dir.mkdir_p(tmp_dir)

      html_buffer = Tremolite::HtmlBuffer.new
      service = PreloadedPostReferencedLinks.new(
        html_buffer: html_buffer,
        posts_path: tmp_dir,
        posts_ext: "md"
      )

      service.populate_referenced_links
      # Should not raise
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir
    end
  end
end
