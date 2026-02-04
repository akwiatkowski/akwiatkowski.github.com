# ##############################################################################
# PHASE6_DEPRECATED - DO NOT REMOVE WITHOUT MIGRATING DEPENDENCIES
# ##############################################################################
#
# DEPRECATED: Use AreaEntity with AreaType::MesoRegion instead
#
# This class is deprecated and will be removed after full migration.
# See PLAN.md for migration status.
#
# Dependencies that need migration:
# - data/src/data_manager.cr (loads lands)
# - data/src/models/town_entity.cr (internal use)
# - data/src/views/post_view/article_view.cr (renders land links)
# - data/src/views/model_view/lands_index_view.cr (lists all lands)
#
# ##############################################################################

struct LandEntity
  Log = ::Log.for(self)

  @slug : String
  @name : String
  @country : String
  @code : String?

  getter :name, :slug, :country, :code

  def initialize(y : YAML::Any)
    @slug = y["slug"].as_s
    @name = y["name"].as_s
    @country = y["country"].as_s
    @code = y["country"].as_s?
  end

  def type
    "" # TODO: remove it
  end

  def view_url
    "/kraina/#{@slug}.html"
  end

  def image_url
    File.join(["/", "images", "land", @slug + ".jpg"])
  end

  def belongs_to_post?(post : Tremolite::Post)
    post.lands.not_nil!.includes?(@slug)
  end
end
