# Simple mock for Post (minimal interface for view testing)
class MockPost
  property slug : String = "test-post"
  property title : String = "Test Post Title"
  property subtitle : String = "Test subtitle"
  property url : String = "/wpisy/test-post.html"
  property date : String = "2024-01-15"
  property image_url : String = "/images/test.jpg"
  property big_thumb_image_url : String? = "/images/test_thumb.jpg"
  property author : String = "Test Author"
  property ready : Bool = true
  property todo : Bool = false
  property finished_at : Time? = nil
  property time : Time = Time.local
  property updated_at : Time = Time.local

  def initialize(
    @slug = "test-post",
    @title = "Test Post Title",
    @ready = true,
  )
  end

  def ready?
    @ready
  end

  def todo?
    @todo
  end

  def was_in?(entity) : Bool
    false
  end

  def content_html_word_count : Int32
    100
  end

  def guuid
    Digest::MD5.hexdigest(self.slug).to_guid
  end
end
