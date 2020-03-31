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
    # keep in mind posts were not yet loaded
    # 0) check what was changed
    mod_watcher.load_from_file
    changes_summary = mod_watcher.changed_summary

    # 1) check if posts files were changed
    if changes_summary[Tremolite::ModWatcher::KEY_POSTS_FILES].size > 0
      @logger.info("Posts were changed")
    end

    if changes_summary[Tremolite::ModWatcher::KEY_YAML_FILES].size > 0
      @logger.info("YAML files were changed")
    end

    if changes_summary[Tremolite::ModWatcher::KEY_YAML_FILES].size > 0
      @logger.info("YAML files were changed")
    end


    # Z) store current state
    # current state is refreshed in `#update_before_save`
    mod_watcher.save_to_file
  end
end
