require "../../crystal/tremolite/src/tremolite"
require "../data/src/blog"

class Commands::ListPostsMissingDetailedRoutes
  def initialize(@env = "full")
    @env_path = File.join(["env", @env])
    @universal_path = "data"

    @blog = Tremolite::Blog.new(
      mod_watcher_yaml_path: File.join([@env_path, "cache", "mod_watcher.yml"]),
      data_path: File.join([@env_path, "data"]),
      public_path: File.join([@env_path, "public"]),
      config_path: File.join([@universal_path, "config"]),
      cache_path: File.join([@env_path, "cache"]),
      layout_path: File.join([@universal_path, "layout"]),
      assets_path: File.join([@universal_path, "assets"]),
      pages_path: File.join([@universal_path, "pages"]),
    ).as(Tremolite::Blog)

    @blog.post_collection.initialize_posts
  end

  def make_it_so
    posts.each do |post|
      next if post.has_detailed_route?
      next unless post.trip?

      unless post.has_detailed_route?
        puts "#{post.slug} is missing detailed route"
      end
    end
  end

  def posts
    return @blog.post_collection.posts.select { |post| post.bicycle? || post.hike? }.as(Array(Tremolite::Post))
  end
end

command = Commands::ListPostsMissingDetailedRoutes.new
command.make_it_so
