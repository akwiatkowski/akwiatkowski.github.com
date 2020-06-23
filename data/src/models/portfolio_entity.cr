require "yaml"

struct PortfolioEntity
  Log = ::Log.for(self)

  @post_slug : String
  @image_filename : String
  @long_desc : String

  getter :post_slug, :image_filename, :long_desc

  def initialize(y : YAML::Any)
    @post_slug = y["post_slug"].to_s
    @image_filename = y["image_filename"].to_s
    @long_desc = y["long_desc"].to_s
  end
end
