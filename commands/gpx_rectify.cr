require "../../tremolite/src/tremolite"
require "../data/src/blog"

env_paths = Array(String).new
env_paths << File.join(["env", "full"])
env_paths << File.join(["env", "dev"])

env_paths.each do |env_path|
  universal_path = "data"
  data_path = File.join([env_path, "data"])
  config_path = File.join([universal_path, "config"])
  ideas_path = File.join([data_path, "ideas"])

  service = ExternalGpxPreprocessor.new(
    config_path: config_path,
    ideas_path: ideas_path
  )

  service.call
end
