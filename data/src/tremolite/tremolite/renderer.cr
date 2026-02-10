# all views are hardcoded
require "./views/base_view"
require "./views/sitemap_generator"
require "./views/robot_generator"

class Tremolite::Renderer
  Log = ::Log.for(self)

  def initialize(
    @html_buffer : Tremolite::HtmlBuffer,
    @data_path : String,
    @output_path : String,
    @assets_path : String,
    @validator : Tremolite::Validator,
    @url_to_output_path_proc : Proc(String, String),
    @image_resizer : Tremolite::ImageResizer,
    @data_manager : Tremolite::DataManager? = nil,
    @mod_watcher : Tremolite::ModWatcher? = nil,
  )
  end

  private def url_to_output_path(url : String) : String
    @url_to_output_path_proc.call(url)
  end

  def render
    # clear # not needed every time
    copy_assets

    process_images(overwrite: false)
    copy_images

    render_all
  end

  # Late-bound: posts for process_images (set after post initialization)
  property posts_for_resize : Array(Tremolite::Post)?

  # Resize all post images to small, thumb, ...
  private def process_images(overwrite : Bool)
    Log.info { "Start image resize" }

    (@posts_for_resize || [] of Tremolite::Post).each do |post|
      @image_resizer.resize_all_images_for_post(post: post, overwrite: overwrite)
    end

    Log.info { "End image resize" }
  end

  # WARNING
  private def clear
    `rm -R public/*`
  end

  private def copy_assets
    `rsync -av #{@assets_path}/ #{@output_path}/`
  end

  private def copy_images
    command = "rsync --mkpath -av #{@data_path}/images #{@output_path}/"
    Log.info { "copy_images: #{command}" }
    `#{command}`
  end

  private def open_to_write_in_public(url : String) : File
    html_output_path = url_to_output_path(url)
    Dir.mkdir_p_dirname(html_output_path)
    f = File.open(html_output_path, "w")
    return f
  end

  private def write_output(view)
    write_output(
      url: view.url,
      content: view.output,
      view: view,
      add_to_sitemap: view.add_to_sitemap?
    )
  end

  private def write_output(
    url : String,
    content : String,
    add_to_sitemap : Bool,
    view,
  )
    # for checking conflicting paths
    @validator.url_written(url)

    # only check if output html was modified
    # input modification is stored elsewhere
    modified = @html_buffer.check(
      url: url,
      content: content,
      output_path: url_to_output_path(url),
      add_to_sitemap: add_to_sitemap
    )

    if modified
      f = open_to_write_in_public(url)
      f.puts(content)
      f.close
      Log.info { "Wrote #{url.colorize(Colorize::COLOR_PATH)}" }
    else
      # nothing
    end
  end

  def copy_or_download_image_if_needed(destination : String, external : String, local : (String | Nil))
    if local
      copy_image_if_needed(local: destination, remote: local)
    end
    download_image_if_needed(local: destination, remote: external)
  end

  private def download_image_if_needed(local : String, remote : String)
    full_image_path = File.join(["data", local])
    if false == File.exists?(full_image_path)
      ImageResizer.download_image(source: remote, output: full_image_path)
    end
  end

  private def copy_image_if_needed(local : String, remote : String)
    full_local_image_path = File.join(["data", local])

    remote = File.join("images", remote) # XXX clean it later
    full_remote_image_path = File.join(["data", remote])

    if false == File.exists?(full_remote_image_path)
      # remote file not exists here ignore
      return
    end

    if false == File.exists?(full_local_image_path)
      # if exists locally don't copy
      ImageResizer.copy_image(source: full_remote_image_path, output: full_local_image_path)
    end
  end
end
