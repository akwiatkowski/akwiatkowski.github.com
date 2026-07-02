class Commands::Pipeline::GpxToRoute
  # Convert a single GPX file into a compacted, private-stripped route JSON written to
  # env/<env>/data/routes/<slug>.json (plus a sibling .gpx), reusing the exact same
  # ExternalGpxPreprocessor / CrystalGpx::Rectifier pipeline as the route-ideas flow.
  #
  # Used by the `trip-draft-post` skill to generate a post's `coords_file` from a ride GPX
  # (which the skill builds from Strava streams). Keeping this a thin reuse of the existing
  # service means simplification thresholds and the private-zone config stay in one place
  # (data/config/gpx_rectifier.yml).
  def run(input_gpx : String, output_slug : String, env : String = "full")
    routes_dir = File.join(["env", env, "data", "routes"])
    Dir.mkdir_p(routes_dir)

    # process_gpx appends .json / .gpx to `output`, so pass the extension-less path.
    output = File.join([routes_dir, output_slug])

    preprocessor = ExternalGpxPreprocessor.new(
      config_path: File.join(["data", "config"]),
      ideas_path: routes_dir, # not used by process_gpx, but required by the constructor
    )
    preprocessor.process_gpx(input: input_gpx, output: output)

    puts "Wrote #{output}.json"
  end
end
