require "tremolite"
require "../data/src/blog"

t = Tremolite::Blog.new(
  mod_watcher_yaml_path: File.join(["cache", "mod_watcher.yml"])
)

t.make_it_so(
  force_full_render: true,
)
