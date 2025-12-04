class Tools::GenerateMapsForIdeas
  ENVS    = ["dev", "full"]
  TARGETS = ["local", "release"]

  IDEAS_SUBPATH = "ideas"

  def initialize(
    @type = "bicycle",
  )
  end

  def make_it_so
    ENVS.each do |env_string|
      process_env(env_string)
    end
  end

  private def process_env(env_string)
    Dir[File.join(["env", env_string, "data", "ideas", "*.json"])].each do |f|
      if File.file?(f)
        generate_map_for_idea(env_string, f)
      end
    end
  end

  private def load_routes_from_json_processed_file(file_path) : Array(PostRouteObject)
    json = File.open(file_path) do |file|
      JSON.parse(file)
    end

    routes = Array(PostRouteObject).new

    json.as_a.each do |route_json|
      single_route = SingleRouteObject.new

      route_json.as_a.each do |coord|
        single_route << [coord[0].as_f, coord[1].as_f]
      end

      route = PostRouteObject.new(
        type: @type,
        route: single_route
      )

      routes << route
    end

    return routes
  end

  private def render_svg_for_routes(routes)
    map = Map::Main.new(
      routes: routes,
      autozoom_width: 700,
      zoom: 9
    )
    return map.to_svg
  end

  private def generate_map_for_idea(env_string, file_path)
    routes = load_routes_from_json_processed_file(file_path)
    svg = render_svg_for_routes(routes)
    slug = Path[file_path].stem

    TARGETS.each do |target_path|
      output_path = File.join([
        "env", env_string, "public", target_path, "photo_map", "for_idea", slug, "normal.svg",
      ])

      Dir.mkdir_p(Path.new(output_path).parent)

      file = File.new(output_path, "w")
      file << svg
      file.close

      puts "#{output_path} - #{svg.size} SVG photo map wrote"
    end
  end
end
