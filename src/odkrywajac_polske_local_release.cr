require "../../crystal/tremolite/src/tremolite"
require "../data/src/blog"

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

t = Tremolite::Blog.new(
  logger: logger,
  mod_watcher_yaml_path: File.join(["cache", "mod_watcher.yml"])
)

t.make_it_so(
  force_full_render: true,
)
