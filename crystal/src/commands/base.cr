module Commands
  ENVS = ["dev", "full"]

  # Shared blog initialization for commands that need post data
  def self.init_blog(env : String) : Tremolite::Blog
    blog = Tremolite::Blog.for_env(env)
    blog.initialize_posts
    blog
  end
end
