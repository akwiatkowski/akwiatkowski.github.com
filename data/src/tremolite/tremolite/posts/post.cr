require "yaml"
require "digest/md5"

class Tremolite::Post
  Log = ::Log.for(self)

  @content_html : String?

  # Late-bound dependencies (set after construction)
  property post_collection : Tremolite::PostCollection?
  property markdown_wrapper : Tremolite::MarkdownWrapper?

  getter :content_string, :header
  getter :url

  # from header or filename
  getter :title, :subtitle, :author, :slug, :time, :category, :path

  def images_dir_url
    "/images/#{self.year}/#{slug}/"
  end

  def image_url
    images_dir_url + "header.jpg"
  end

  def public_image_url
    op = File.join([@output_path, image_url])
    if File.extname(op) == ""
      op = File.join(op, "index.html")
    end
    op
  end

  def date
    @time.to_s("%Y-%m-%d")
  end

  def year
    @time.year
  end

  def <=>(other)
    self.time <=> other.time
  end

  def updated_at
    File.info(@path).modification_time
  end

  # for atom feed
  def guuid
    return Digest::MD5.hexdigest(self.slug).to_guid
  end

  # end of header getters

  LINE_JOIN_STRING = "\n"

  def parse
    s = File.read(@path)

    header_idxs = Array(Int32).new

    s.lines.each_with_index do |line, i|
      if line =~ /\-{3,100}/
        header_idxs << i
      end
    end

    if header_idxs.size >= 2
      header_string = s.lines[(header_idxs[0] + 1)...(header_idxs[1])].join(LINE_JOIN_STRING) # \n, before was ""
      @header = YAML.parse(header_string)

      @content_string = s.lines[(header_idxs[1] + 1)..(-1)].join(LINE_JOIN_STRING)

      # is valid, process rest
      process
    else
      return nil
    end
  end

  # to allow using jekkyl-like post_url functions
  # we need to process to html after initial post processing
  #
  # NOTE you must execute this if you want to have functions processed
  def content_html : String
    if @content_html.nil?
      @content_html = @markdown_wrapper.not_nil!.to_html(string: @content_string, post: self)
    end

    return @content_html.not_nil!
  end

  def process_header
    @title = @header["title"].to_s
    @subtitle = @header["subtitle"].to_s
    @author = @header["author"].to_s
    @category = @header["categories"].to_s
    begin
      @time = Time.parse(
        time: @header["date"].to_s,
        pattern: "%Y-%m-%d %H:%M:%S",
        location: Time::Location.load_local
      )
    rescue e : ArgumentError
      Log.fatal { "#{@slug.to_s} time error #{@header["date"].to_s}" }
      raise e
    end
  end

  def process_paths
    @url = "/" + File.join([@category.to_s, @slug])
  end

  # by default all posts are visible, can be overriden
  def visible?
    true
  end
end
