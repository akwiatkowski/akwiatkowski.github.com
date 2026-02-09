module Commands
  ENVS = ["dev", "full"]

  # Shared blog initialization for commands that need post data
  def self.init_blog(env : String) : Tremolite::Blog
    env_path = File.join(["env", env])
    universal_path = "data"

    blog = Tremolite::Blog.new(
      mod_watcher_yaml_path: File.join([env_path, "cache", "mod_watcher.yml"]),
      data_path: File.join([env_path, "data"]),
      output_path: File.join([env_path, "public"]),
      config_path: File.join([universal_path, "config"]),
      cache_path: File.join([env_path, "cache"]),
      layout_path: File.join([universal_path, "layout"]),
      assets_path: File.join([universal_path, "assets"]),
      pages_path: File.join([universal_path, "pages"]),
    ).as(Tremolite::Blog)

    blog.post_collection.initialize_posts
    blog
  end
end
