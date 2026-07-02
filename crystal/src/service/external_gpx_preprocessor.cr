class ExternalGpxPreprocessor
  # it's safer to run external command instead
  def initialize(config_path : String, @ideas_path : String)
    config_file_path = File.join([config_path, "gpx_rectifier.yml"])
    @config = YAML.parse(File.read(config_file_path))

    @private_mode = @config["private"]["enabled"].as_bool
    @private_range = @config["private"]["range"].as_i
    @private_lat = @config["private"]["lat"].as_f
    @private_lon = @config["private"]["lon"].as_f

    @min_bearing_change = @config["settings"]["min_bearing_change"].as_f
    @min_distance_for_bearing = @config["settings"]["min_distance_for_bearing"].as_f
    @max_distance = @config["settings"]["max_distance"].as_f
  end

  def call
    process_ideas_gpx
  end

  def process_ideas_gpx
    ideas_input_path = File.join([@ideas_path, "raw"])

    Dir[File.join([ideas_input_path, "*.gpx"])].each do |f|
      if File.file?(f)
        process_ideas_gpx(f)
      end
    end
  end

  def process_ideas_gpx(idea_route_raw_path)
    process_gpx(
      input: idea_route_raw_path,
      output: File.join([@ideas_path, Path[idea_route_raw_path].stem])
    )
  end

  def process_gpx(input, output)
    CrystalGpx::Rectifier.process(
      min_bearing_change: @min_bearing_change,
      min_distance_for_bearing: @min_distance_for_bearing,
      max_distance: @max_distance,
      files: input,
      out_name: output,

      private_mode: @private_mode,
      private_range: @private_range,
      private_lat: @private_lat,
      private_lon: @private_lon,
    )
  end
end
