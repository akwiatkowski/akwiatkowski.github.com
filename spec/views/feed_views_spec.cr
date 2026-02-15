require "../spec_helper"

# Helper to create a minimal Tremolite::Post from a temp file
private def create_test_post(slug : String = "2024-01-15-test-post", title : String = "Test Post", subtitle : String = "A subtitle", todo : Bool = false) : Tremolite::Post
  dir = File.tempname("feed_test")
  Dir.mkdir_p(dir)
  path = File.join(dir, "#{slug}.md")
  tags_line = todo ? "tags: [todo]" : ""
  File.write(path, <<-MD
  ---
  title: "#{title}"
  subtitle: "#{subtitle}"
  author: "Test Author"
  categories: "trip"
  date: "2024-01-15 10:00:00"
  #{tags_line}
  ---

  Some content here.
  MD
  )
  post = Tremolite::Post.new(path: path)
  post.photo_tags = [] of PhotoTagEntity
  post.parse
  post
end

describe SpecialView::RssGenerator do
  it "generates valid RSS XML" do
    post = create_test_post
    rss = SpecialView::RssGenerator.new(
      posts: [post],
      site_title: "Test Blog",
      site_url: "https://example.com",
      site_desc: "A test blog",
    )
    output = rss.output
    output.should contain("<?xml")
    output.should contain("<rss")
    output.should contain("<channel>")
    output.should contain("<title>Test Blog</title>")
  end

  it "includes post items" do
    post = create_test_post(title: "My Trip")
    rss = SpecialView::RssGenerator.new(
      posts: [post],
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    output = rss.output
    output.should contain("<item>")
    output.should contain("<title>My Trip</title>")
    output.should contain("https://example.com/")
  end

  it "excludes todo posts" do
    post = create_test_post(todo: true)
    rss = SpecialView::RssGenerator.new(
      posts: [post],
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    output = rss.output
    output.should_not contain("<item>")
  end

  it "defaults to /feed.xml URL" do
    rss = SpecialView::RssGenerator.new(
      posts: [] of Tremolite::Post,
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    rss.url.should eq "/feed.xml"
  end
end

describe SpecialView::AtomGenerator do
  it "generates valid Atom XML" do
    post = create_test_post
    atom = SpecialView::AtomGenerator.new(
      posts: [post],
      site_title: "Test Blog",
      site_url: "https://example.com",
      site_desc: "A test blog",
    )
    output = atom.output
    output.should contain("<?xml")
    output.should contain("<feed")
    output.should contain("<title>Test Blog</title>")
  end

  it "includes post entries with uuid" do
    post = create_test_post(title: "My Atom Trip")
    atom = SpecialView::AtomGenerator.new(
      posts: [post],
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    output = atom.output
    output.should contain("<entry>")
    output.should contain("<title>My Atom Trip</title>")
    output.should contain("urn:uuid:")
  end

  it "includes author name when provided" do
    atom = SpecialView::AtomGenerator.new(
      posts: [] of Tremolite::Post,
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
      author_name: "Jan Kowalski",
    )
    output = atom.output
    output.should contain("<author>")
    output.should contain("<name>Jan Kowalski</name>")
  end

  it "excludes todo posts" do
    post = create_test_post(todo: true)
    atom = SpecialView::AtomGenerator.new(
      posts: [post],
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    output = atom.output
    output.should_not contain("<entry>")
  end

  it "defaults to /feed_atom.xml URL" do
    atom = SpecialView::AtomGenerator.new(
      posts: [] of Tremolite::Post,
      site_title: "Blog",
      site_url: "https://example.com",
      site_desc: "Desc",
    )
    atom.url.should eq "/feed_atom.xml"
  end
end
