require "./image_resizer"
require "./data_manager"
require "./post"
require "./renderer"
require "./post_function_parser"
require "./validator"
require "./mod_watcher"

class Tremolite::Blog
  # 1) check what was changed:
  #   * posts
  #

  def make_it_so
    # ** render all just like the old way
    if mod_watcher.enabled == false
      @logger.debug("#{self.class}: render all START")
      renderer.render_all
      @logger.debug("#{self.class}: render all DONE")
      return
    end

    # ** new way is to render what has changed

    # keep in mind posts were not yet loaded
    # 0) check what was changed
    mod_watcher.load_from_file
    changes_summary = mod_watcher.changed_summary

    # only these posts will be updated
    # load md, process md -> html, while converting create PhotoEntity
    # exif data is needed (photo link to map, photo data attribs)
    # so we still need to update exif which require loading db
    # because of that I'll split exif and photo data to separate files
    post_paths_to_update = changes_summary[Tremolite::ModWatcher::KEY_POSTS_FILES]

    # if yaml config was changed we need to re-render all posts and
    if changes_summary[Tremolite::ModWatcher::KEY_YAML_FILES].size > 0
      @logger.debug("#{self.class}: YAML changed -> rendering all posts + YAML views")
      render_yaml = true
    else
      render_yaml = false
    end

    # ** the real render part

    # render changed posts
    @logger.debug("#{self.class}: PostCollection#initialize_posts")
    post_collection.initialize_posts
    @logger.debug("#{self.class}: PostCollection#initialize_posts DONE")

    post_to_render = post_collection.posts.select do |post|
      post_paths_to_update.includes?(post.path)
    end

    post_to_render.each do |post|
      @logger.debug("#{self.class}: preparing content #{post.slug}")
      post.content_html
      @logger.debug("#{self.class}: rendering #{post.slug}")
      renderer.render_post(post)
      @logger.debug("#{self.class}: DONE #{post.slug}")
    end

    # Z) store current state
    # current state is refreshed in `#update_before_save`
    mod_watcher.save_to_file
  end
end
