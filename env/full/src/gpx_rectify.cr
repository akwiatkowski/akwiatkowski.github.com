require "../../../../tremolite/src/tremolite"
require "../../../data/src/blog"

env_path = File.join(["env", "full"])

universal_path = "data"
data_path = File.join([env_path, "data"])
config_path = File.join([universal_path, "config"])
ideas_path = File.join([universal_path, "ideas"])

service = ExternalGpxPreprocessor.new(
  config_path: config_path,
  ideas_path: ideas_path
)

service.call
