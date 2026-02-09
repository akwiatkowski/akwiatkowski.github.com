require "yaml"

class Tremolite::DataManager
  Log = ::Log.for(self)

  def load_config
    path = File.join([@config_path, "config.yml"])

    YAML.parse(File.read(path)).as_h.each do |key, value|
      @config_hash[key.to_s] = value.to_s
    end
  end

  def [](key : String) : String
    return @config_hash[key]
  end

  def []?(key : String) : (String | Nil)
    return @config_hash[key]?
  end
end
