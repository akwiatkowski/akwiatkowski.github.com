require "../base"

class Commands::Tools::ListMissingRoutes
  def initialize(@env : String = "full")
  end

  def run
    blog = Commands.init_blog(@env)
    posts = blog.post_collection.posts

    trip_posts = posts.select { |post| post.bicycle? || post.hike? }
    missing = trip_posts.reject { |post| post.has_detailed_route? }

    if missing.empty?
      puts "All #{trip_posts.size} trip posts have detailed routes."
    else
      puts "Posts missing detailed route (#{missing.size} of #{trip_posts.size} trip posts):"
      missing.each do |post|
        puts "  #{post.slug}"
      end
    end
  end
end
