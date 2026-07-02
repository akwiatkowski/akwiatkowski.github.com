require "../base"

class Commands::Pipeline::GpxRectify
  def run
    Commands::ENVS.each do |env|
      puts "\n=== Processing env: #{env} ==="
      process_env(env)
    end
    puts "\nDone!"
  end

  private def process_env(env : String)
    env_path = File.join(["env", env])
    universal_path = "data"
    config_path = File.join([universal_path, "config"])
    ideas_path = File.join([env_path, "data", "ideas"])

    unless Dir.exists?(File.join([ideas_path, "raw"]))
      puts "  No raw ideas directory, skipping"
      return
    end

    service = ExternalGpxPreprocessor.new(
      config_path: config_path,
      ideas_path: ideas_path,
    )

    service.call
    puts "  Processed GPX files in #{ideas_path}"
  end
end
