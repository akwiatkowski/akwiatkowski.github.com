require "log"
require "colorize"
require "./std/colorize" # used colors defined here
require "./std/float"
require "./std/string" # to_guid
require "./std/time"   # at_beginning_of_next_month

require "./posts/post_collection"
require "./renderer"
require "./image_resizer"
require "./data_manager"
require "./markdown_wrapper"
require "./html_buffer"
require "./validator"
require "./mod_watcher"

require "./uploader"

Log.setup_from_env

class Tremolite::Blog
  Log = ::Log.for(self)

  def self.for_env(env : String, target : String = "local") : Blog
    env_path = "env/#{env}"
    Blog.new(
      mod_watcher_yaml_path: File.join(env_path, "cache", "mod_watcher.yml"),
      data_path: File.join(env_path, "data"),
      output_path: File.join(env_path, "public", target),
      config_path: "data/config",
      cache_path: File.join(env_path, "cache"),
      layout_path: "data/layout",
      assets_path: "data/assets",
      pages_path: "data/pages",
    )
  end

  def initialize(
    @data_path = "data",
    @posts_ext = "md",
    @cache_path = "cache",
    @output_path = "public",
    @config_path = @data_path,
    @layout_path = File.join([@data_path, "layout"]).to_s,
    @assets_path = File.join([@data_path, "assets"]).to_s,
    @pages_path = File.join([@data_path, "pages"]).to_s,
    @mod_watcher_yaml_path : String? = nil,
  )
    @posts_path = File.join([@data_path, "posts"])
    # end of semivariable configs

    Log.info { "START" }

    # 1. Core infrastructure (no dependencies)
    @html_buffer = Tremolite::HtmlBuffer.new

    # 2. Validator (needs html_buffer)
    @validator = Tremolite::Validator.new(html_buffer: @html_buffer.not_nil!)

    # 3. Renderer (needs html_buffer + paths)
    @renderer = Tremolite::Renderer.new(
      html_buffer: @html_buffer.not_nil!,
      data_path: @data_path,
      output_path: @output_path,
      assets_path: @assets_path,
    )

    # 4. ImageResizer (needs paths)
    @image_resizer = Tremolite::ImageResizer.new(
      data_path: @data_path,
      output_path: @output_path,
    )

    # 5. DataManager (needs paths + html_buffer)
    @data_manager = Tremolite::DataManager.new(
      config_path: @config_path.to_s,
      data_path: @data_path,
      cache_path: @cache_path,
      output_path: @output_path,
      posts_path: @posts_path,
      posts_ext: @posts_ext,
      html_buffer: @html_buffer.not_nil!,
    )

    # 6. MarkdownWrapper — lazy initialized (needs context which needs self)

    # 7. ModWatcher (needs file_path + paths for current_state_of)
    @mod_watcher = Tremolite::ModWatcher.new(
      file_path: @mod_watcher_yaml_path,
      posts_path: @posts_path,
      posts_ext: @posts_ext,
      data_path: @data_path,
      exif_db_path: @data_manager.not_nil!.exif_db.exif_db_file_parent_path,
    )

    # 8. PostCollection (needs paths)
    @post_collection = Tremolite::PostCollection.new(
      posts_path: @posts_path,
      posts_ext: @posts_ext,
      data_path: @data_path,
      output_path: @output_path,
    )

    # --- Wire late-bound dependencies ---

    # Renderer needs validator + url_to_output_path + image_resizer
    @renderer.not_nil!.validator = @validator
    @renderer.not_nil!.url_to_output_path_proc = ->url_to_output_path(String)
    @renderer.not_nil!.image_resizer = @image_resizer

    # Validator needs area_data_loader + posts (set lazily after post init in make_it_so)

    # PostCollection needs photo_tags for Post construction
    @post_collection.not_nil!.photo_tags = @data_manager.not_nil!.photo_tags

    # Renderer needs data_manager and mod_watcher for custom renderer
    @renderer.not_nil!.data_manager = @data_manager
    @renderer.not_nil!.mod_watcher = @mod_watcher
  end

  def initialize_posts
    # Set deps on post_collection before initializing
    @post_collection.not_nil!.exif_db = @data_manager.not_nil!.exif_db
    @post_collection.not_nil!.markdown_wrapper = markdown_wrapper
    @post_collection.not_nil!.initialize_posts

    # Wire post-init dependencies
    @validator.not_nil!.area_data_loader = @data_manager.not_nil!.area_data_loader
    @validator.not_nil!.posts = @post_collection.not_nil!.posts
    @renderer.not_nil!.all_posts = @post_collection.not_nil!.posts
    @renderer.not_nil!.posts_for_resize = @post_collection.not_nil!.posts
  end

  # getters

  property :posts_path, :posts_ext
  getter :data_path, :output_path, :config_path, :cache_path,
    :layout_path, :assets_path, :pages_path
  getter :image_resizer, :html_buffer, :validator, :mod_watcher
  getter :server

  def data_manager
    return @data_manager.not_nil!
  end

  def post_collection
    return @post_collection.not_nil!
  end

  def markdown_wrapper
    @markdown_wrapper ||= Tremolite::MarkdownWrapper.new(context: context)
  end

  def renderer
    return @renderer.not_nil!
  end

  def validator
    return @validator.not_nil!
  end

  def mod_watcher
    return @mod_watcher.not_nil!
  end

  # end of getters

  # begin of core methods

  def render
    rendered.render
    validator.run
    mod_watcher.save_to_file
  end

  def run
    render
    run_server
  end

  def run_server
    @server.run
  end

  # the most important methods

  def url_to_output_path(url : String)
    op = File.join([@output_path, url])
    if File.extname(op) == ""
      op = File.join(op, "index.html")
    end
    return op
  end
end
