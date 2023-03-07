require "../../../../crystal/tremolite/src/tremolite"
require "../../../data/src/blog"

env_path = File.join(["env", "dev"])
universal_path = "data"

t = Tremolite::Blog.new(
  mod_watcher_yaml_path: File.join([env_path, "cache", "mod_watcher.yml"]),
  data_path: File.join([env_path, "data"]),
  public_path: File.join([env_path, "public"]),
  config_path: File.join([universal_path, "config"]),
  cache_path: File.join([env_path, "cache"]),
  layout_path: File.join([universal_path, "layout"]),
  assets_path: File.join([universal_path, "assets"]),
  pages_path: File.join([universal_path, "pages"]),
)

t.make_it_so(
  force_full_render: false,
)
