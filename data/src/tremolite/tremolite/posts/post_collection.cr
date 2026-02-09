require "./post"

class Tremolite::PostCollection
  Log = ::Log.for(self)

  # Late-bound dependencies (set after construction)
  property data_path : String = ""
  property output_path : String = ""
  property markdown_wrapper : Tremolite::MarkdownWrapper?

  def initialize(
    @posts_path : String,
    @posts_ext : String,
  )
    # when latest Post was updated
    # used in RSS/Atom
    @last_updated_at = Time.unix(0)
    @posts = Array(Tremolite::Post).new

    Log.info { "START" }
  end

  getter :posts, :last_updated_at

  def initialize_posts
    Log.info { "initialize_posts" }
    @posts.clear

    each_post_file do |path|
      begin
        p = Tremolite::Post.new(path: path, data_path: @data_path, output_path: @output_path)
        p.markdown_wrapper = @markdown_wrapper
        p.post_collection = self
        p.photo_tags = @photo_tags
        p.exif_db = @exif_db
        p.parse
      rescue e : IndexError
        Log.error { "error in #{path}" }
        raise e
      end

      Log.debug { "Added #{p.slug}" }

      if @last_updated_at.nil? || @last_updated_at.not_nil! < p.updated_at
        @last_updated_at = p.updated_at
      end

      # add only visible posts
      @posts << p if p.visible?
    end

    @posts = @posts.sort { |a, b| a.time <=> b.time }
  end

  def next_to(post : Tremolite::Post) : (Tremolite::Post | Nil)
    i = @posts.index(post)
    if i && i < (@posts.size - 1)
      return @posts[i + 1]
    else
      return nil
    end
  end

  def prev_to(post : Tremolite::Post) : (Tremolite::Post | Nil)
    i = @posts.index(post)
    if i && i > 0
      return @posts[i - 1]
    else
      return nil
    end
  end

  def posts_from_latest
    @posts.reverse
  end

  def each_post_from_latest(&block : Tremolite::Post -> Nil)
    posts_from_latest.each do |post|
      block.call(post)
    end
  end
end
