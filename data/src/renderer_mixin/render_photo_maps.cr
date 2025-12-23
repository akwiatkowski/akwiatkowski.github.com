module RendererMixin::RenderPhotoMaps
  def render_all_photo_maps
    render_photo_maps_voivodeships
    render_photo_maps_posts
    render_photo_maps_ideas

    render_photo_maps_global

    render_photo_maps_for_tagged_photos

    # all rendered photomaps will have url here
    render_photo_maps_index
  end

  # # Global

  def render_photo_maps_global
    overall_view = PhotoMap::GlobalGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("overall"),
      zoom: Map::DEFAULT_OVERALL_ZOOM,
      photo_size: Map::DEFAULT_OVERALL_PHOTO_SIZE,
    )
    add_photomap_globals("Ogólne", overall_view)
    write_output(overall_view)

    coarse_view = PhotoMap::GlobalGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("coarse"),
      zoom: Map::DEFAULT_COARSE_ZOOM,
      photo_size: Map::DEFAULT_COARSE_PHOTO_SIZE,
    )
    add_photomap_globals("Z grubsza", coarse_view)
    write_output(coarse_view)

    small_view = PhotoMap::GlobalGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("small"),
      zoom: Map::DEFAULT_SMALL_ZOOM,
      photo_size: Map::DEFAULT_SMALL_PHOTO_SIZE,
    )
    add_photomap_globals("Małe", small_view)
    write_output(small_view)

    # new, animated SVG
    small_animated_view = PhotoMap::GlobalAnimatedRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("small_animated"),
      zoom: Map::DEFAULT_SMALL_ZOOM
    )
    add_photomap_globals("Animowana", small_animated_view)
    write_output(small_animated_view)

    small_detailed_view = PhotoMap::GlobalGridMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("small_detailed"),
      zoom: Map::DEFAULT_SMALL_DETAILED_ZOOM,
      photo_size: Map::DEFAULT_SMALL_DETAILED_PHOTO_SIZE,
    )

    add_photomap_globals("Mała i szczegółowa", small_detailed_view)
    write_output(small_detailed_view)

    detailed_view = PhotoMap::GlobalGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("detailed"),
      zoom: Map::DEFAULT_DETAILED_ZOOM,
      photo_size: Map::DEFAULT_DETAILED_PHOTO_SIZE,
    )
    add_photomap_globals("Szczegółowe", detailed_view)
    write_output(detailed_view)

    # circle dots
    dots_view = PhotoMap::GlobalDotsMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("dots"),
      zoom: Map::DEFAULT_COARSE_ZOOM,
      photo_size: Map::DEFAULT_DETAILED_PHOTO_SIZE,
      dot_radius: Map::DEFAULT_DOT_RADIUS,
    )
    add_photomap_globals("Kółko-zdjęcia", dots_view)
    write_output(dots_view)
  end

  private def add_photomap_globals(name, view)
    # TODO: add abstract class for SVG views
    @photomaps_global ||= Hash(String, PhotoMap::AbstractSvgView).new
    @photomaps_global.not_nil![name] = view
  end

  private def url_photomap_globals(slug : String)
    return Map::LinkGenerator.url_photomap_for_main(slug: slug)
  end

  # # Ideas

  def render_photo_maps_ideas
    @blog.data_manager.ideas.not_nil!.each do |idea|
      render_photo_map_for_idea(idea: idea)
    end
  end

  protected def render_photo_map_for_idea(idea : IdeaEntity)
    Log.debug { "render_photo_map_for_idea #{idea.slug}" }

    idea_map_view = PhotoMap::IdeaRouteMapSvgView.new(
      blog: @blog,
      idea: idea
    )

    write_output(idea_map_view)
    Log.debug { "#{idea.slug} - render_photo_map_for_idea done" }
  end

  # # Posts

  def render_photo_maps_posts
    @blog.post_collection.posts.not_nil!.each do |post|
      # removed `post.self_propelled?` because event train/car
      # trips should have rendered map
      if post.detailed_routes && post.detailed_routes.not_nil!.size > 0
        render_big_photo_map_for_post(post)
        render_small_photo_map_for_post(post)
      end
    end
  end

  # to get rid of strava maps
  # strava is ok but I don't like how it's being rendered
  protected def render_small_photo_map_for_post(post : Tremolite::Post)
    # TODO refactor post coords into something not ugly

    if post.detailed_routes.not_nil![0].route.size > 0
      Log.debug { "render_photo_maps_posts #{post.slug}" }

      post_map_view = PhotoMap::PostRouteMapSvgView.new(
        blog: @blog,
        post: post,
        url: url_photomap_for_post_small(post),
      )

      add_photomap_for_post_small(post, post_map_view)
      write_output(post_map_view)
      Log.debug { "#{post.slug} - render_photo_maps_posts SMALL done" }
    else
      Log.debug { "#{post.slug} - no coords" }
    end
  end

  protected def render_big_photo_map_for_post(post : Tremolite::Post)
    # TODO refactor post coords into something not ugly

    if post.detailed_routes.not_nil![0].route.size > 0
      Log.debug { "render_photo_maps_posts #{post.slug}" }

      post_map_view = PhotoMap::PostBigMapSvgView.new(
        blog: @blog,
        post: post,
        url: url_photomap_for_post_big(post),
      )

      add_photomap_for_post_big(post, post_map_view)
      write_output(post_map_view)
      Log.debug { "#{post.slug} - render_photo_maps_posts BIG done" }
    else
      Log.debug { "#{post.slug} - no coords" }
    end
  end

  private def add_photomap_for_post_big(post, view)
    @photomaps_for_post_big ||= Hash(Tremolite::Post, PhotoMap::PostBigMapSvgView).new
    @photomaps_for_post_big.not_nil![post] = view
  end

  private def add_photomap_for_post_small(post, view)
    @photomaps_for_post_small ||= Hash(Tremolite::Post, PhotoMap::PostRouteMapSvgView).new
    @photomaps_for_post_small.not_nil![post] = view
  end

  private def url_photomap_for_post_big(post : Tremolite::Post)
    return Map::LinkGenerator.url_photomap_for_post_big(post: post)
  end

  private def url_photomap_for_post_small(post : Tremolite::Post)
    return Map::LinkGenerator.url_photomap_for_post_small(post: post)
  end

  # # Voivodesips

  def render_photo_maps_voivodeships
    @blog.data_manager.voivodeships.not_nil!.each do |voivodeship|
      render_photo_map_for_voivodeship(voivodeship)
    end
  end

  protected def render_photo_map_for_voivodeship(voivodeship : VoivodeshipEntity)
    # select posts in voivodeship
    # and render mini-map (not so mini)
    Log.debug { "render_photo_maps_voivodeships #{voivodeship.slug}" }

    # used for photos
    # TODO maybe use similar for routes but it will require some work
    voivodeship_coord_range = CoordRange.new(voivodeship)

    # for now select post slugs assigned for that voivodeship
    post_slugs = @blog.post_collection.posts.select do |post|
      post.was_in_voivodeship(voivodeship)
    end.map do |post|
      post.slug
    end

    voivodeship_view = PhotoMap::MultiplePostsGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_voivodeship_big(voivodeship),
      zoom: Map::DEFAULT_VOIVODESHIP_ZOOM,
      photo_size: Map::DEFAULT_VOIVODESHIP_PHOTO_SIZE,
      fixed_coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    add_photomap_for_voivodeship_big(voivodeship, voivodeship_view)
    write_output(voivodeship_view)

    voivodeship_small_view = PhotoMap::MultiplePostsGridAndRoutesMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_voivodeship_small(voivodeship),
      zoom: Map::DEFAULT_VOIVODESHIP_SMALL_ZOOM,
      photo_size: Map::DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE,
      fixed_coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    add_photomap_for_voivodeship_small(voivodeship, voivodeship_small_view)
    write_output(voivodeship_small_view)
  end

  private def add_photomap_for_voivodeship_big(voivodeship, view)
    @photomaps_for_voivodeship_big ||= Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView).new
    @photomaps_for_voivodeship_big.not_nil![voivodeship.name] = view
  end

  private def url_photomap_for_voivodeship_big(voivodeship : VoivodeshipEntity)
    return Map::LinkGenerator.url_photomap_for_voivodeship_big(voivodeship: voivodeship)
  end

  private def add_photomap_for_voivodeship_small(voivodeship, view)
    @photomaps_for_voivodeship_small ||= Hash(String, PhotoMap::MultiplePostsGridAndRoutesMapSvgView).new
    @photomaps_for_voivodeship_small.not_nil![voivodeship.name] = view
  end

  private def url_photomap_for_voivodeship_small(voivodeship : VoivodeshipEntity)
    return Map::LinkGenerator.url_photomap_for_voivodeship_small(voivodeship: voivodeship)
  end

  # # PhotoEntity tags, not Post tag

  # TODO: rural, winter, macro, city, night, bird..need to be tagged
  # TODO convert insect -> macro
  SELECTED_PHOTO_TAGS = ["rural", "winter", "city", "night", "macro", "portfolio", "cat", "best", "good", "timeline"]

  def render_photo_maps_for_tagged_photos
    # PhotoEntity.tags_dictionary.each do |tag|
    #   render_photo_maps_for_tag(tag)
    # end

    SELECTED_PHOTO_TAGS.sort.each do |tag|
      render_photo_maps_for_tag(tag)
    end
  end

  def render_photo_maps_for_tag(tag : String)
    photo_entities = @blog.data_manager.exif_db.all_flatten_photo_entities.select do |photo_entity|
      photo_entity.tags.includes?(tag)
    end

    photomap_view = PhotoMap::MultiplePhotoEntitiesGridMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_tag(tag),
      zoom: Map::DEFAULT_TAG_ZOOM,
      photo_size: Map::DEFAULT_TAG_PHOTO_SIZE,
      photo_entities: photo_entities,
    )
    add_photomap_for_tag(tag, photomap_view)
    write_output(photomap_view)
  end

  private def add_photomap_for_tag(tag : String, view)
    @photomaps_for_tag ||= Hash(String, PhotoMap::MultiplePhotoEntitiesGridMapSvgView).new
    @photomaps_for_tag.not_nil![tag] = view
  end

  private def url_photomap_for_tag(tag : String)
    return Map::LinkGenerator.url_photomap_for_tag(slug: tag)
  end

  # # Index page

  def render_photo_maps_index
    html_view = PhotoMap::IndexView.new(
      blog: @blog,
      url: "/mapa_zdjec.html",
      photomaps_for_tag: @photomaps_for_tag.not_nil!,
      photomaps_for_voivodeship_big: @photomaps_for_voivodeship_big.not_nil!,
      photomaps_for_voivodeship_small: @photomaps_for_voivodeship_small.not_nil!,
      photomaps_for_post_big: @photomaps_for_post_big.not_nil!,
      photomaps_for_post_small: @photomaps_for_post_small.not_nil!,
      photomaps_global: @photomaps_global.not_nil!,
    )
    write_output(html_view)
  end

  # # Debug

  def render_all_photo_maps_debug
    render_photo_maps_debug_post
    render_photo_maps_debug_voivodeship
  end

  def render_photo_maps_debug_post
    # sleep 0.01
    puts "DEBUG"
    slug = "2021-09-26-rowerem-wokol-jeziora-kowalskiego"
    post = @blog.post_collection.posts.not_nil!.select do |post|
      post.slug == slug
    end.first

    render_big_photo_map_for_post(post)
    render_small_photo_map_for_post(post)
    puts "SLEEPING"
    # sleep 500
  end

  def render_photo_maps_debug_voivodeship
    puts "DEBUG"
    @blog.data_manager.voivodeships.not_nil!.each do |voivodeship|
      next unless voivodeship.slug == "wielkopolskie"
      render_photo_map_for_voivodeship(voivodeship)
      puts "SLEEPING"
      # sleep 5
    end
  end
end
