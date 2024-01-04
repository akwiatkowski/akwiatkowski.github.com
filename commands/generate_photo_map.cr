require "../../crystal/tremolite/src/tremolite"
require "../data/src/blog"

require "../data/src/services/map/base"

class Commands::GeneratePhotoMap
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
      generate_map_for_post(post)
    end
  end

  def generate_map_for_post(post)
    map = Map::Main.new(
      posts: [post],
      photos: Array(PhotoEntity).new
      # photo_size: Map::DEFAULT_PHOTO_SIZE,
      # tile: @tile,
      # zoom: @zoom,
      #
      # # just for this kind of map
      # post_slugs: [@post.slug],
      # type: Map::MapType::PhotoDots,
      # only_in_poland: true,
      # photo_entities: photo_entities,
      # render_routes: true,
      # photo_link_to: Map::MapPhotoLinkTo::LinkToPhoto,
      # routes_type: Map::MapRoutesType::Static,
      # coord_range: coord_range,
      # custom_width: POST_ROUTE_SVG_WIDTH,
      #
      # todo_do_not_crop_routes: true
    )
    svg = map.to_svg

    path = File.join(@env_path, "public", "tmp", post.slug + ".svg")

    Dir.mkdir_p(Path.new(path).parent)

    file = File.new(path, "w")
    file << svg
    file.close

    puts "done #{path}"
  end

  def posts
    # return [@blog.post_collection.posts.select { |post| post.bicycle? }.last].as(Array(Tremolite::Post))
    return @blog.post_collection.posts.select { |post| post.bicycle? }.as(Array(Tremolite::Post))
  end
end

command = Commands::GeneratePhotoMap.new
command.make_it_so
