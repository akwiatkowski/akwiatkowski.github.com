require "../../../../tremolite/src/tremolite"
require "../../../data/src/blog"

env_path = File.join(["env", "full"])
universal_path = "data"

blog = Tremolite::Blog.new(
  mod_watcher_yaml_path: File.join([env_path, "cache", "mod_watcher.yml"]),
  data_path: File.join([env_path, "data"]),
  output_path: File.join([env_path, "public", "local"]),
  config_path: File.join([universal_path, "config"]),
  cache_path: File.join([env_path, "cache"]),
  layout_path: File.join([universal_path, "layout"]),
  assets_path: File.join([universal_path, "assets"]),
  pages_path: File.join([universal_path, "pages"]),
)

# loads posts. w/o it array is empty
blog.post_collection.initialize_posts
blog.post_collection.posts.each do |post|
  # load and process photos with exif data
  # little overkill here
  blog.data_manager.exif_db.initialize_post_photos_exif(post)

  post.published_photo_entities.each do |photo_entity|
    puts photo_entity.tags.inspect
    # TODO: put code here
  end
end
