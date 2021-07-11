module RendererMixin::RenderPhotoMaps
  def render_all_photo_maps
    render_photo_maps_voivodeships
    render_photo_maps_posts

    render_photo_maps_global

    render_photo_maps_for_tagged_photos

    # all rendered photomaps will have url here
    render_photo_maps_index
  end

  # # Global

  def render_photo_maps_global
    overall_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("overall"),
      zoom: Map::DEFAULT_OVERALL_ZOOM,
      quant_size: Map::DEFAULT_OVERALL_PHOTO_SIZE,
    )
    add_photomap_globals("Ogólne", overall_view)
    write_output(overall_view)

    coarse_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("coarse"),
      zoom: Map::DEFAULT_COARSE_ZOOM,
      quant_size: Map::DEFAULT_COARSE_PHOTO_SIZE,
    )
    add_photomap_globals("Z grubsza", coarse_view)
    write_output(coarse_view)

    small_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("small"),
      zoom: Map::DEFAULT_SMALL_ZOOM,
      quant_size: Map::DEFAULT_SMALL_PHOTO_SIZE,
    )
    add_photomap_globals("Małe", small_view)
    write_output(small_view)

    detailed_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("small_detailed"),
      zoom: Map::DEFAULT_SMALL_DETAILED_ZOOM,
      quant_size: Map::DEFAULT_SMALL_DETAILED_PHOTO_SIZE,
      render_routes: false
    )
    add_photomap_globals("Mała i szczegółowa", detailed_view)
    write_output(detailed_view)

    detailed_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_globals("detailed"),
      zoom: Map::DEFAULT_DETAILED_ZOOM,
      quant_size: Map::DEFAULT_DETAILED_PHOTO_SIZE,
    )
    add_photomap_globals("Szczegółowe", detailed_view)
    write_output(detailed_view)

    # XXX: overriden by PhotoMap::Index
    # html_view = PhotoMapHtmlView.new(
    #   blog: @blog,
    #   url: "/photo_map",
    #   svg_url: overall_view.url
    # )
    # write_output(html_view)
  end

  private def add_photomap_globals(name, view)
    @photomaps_global ||= Hash(String, PhotoMapSvgView).new
    @photomaps_global.not_nil![name] = view
  end

  private def url_photomap_globals(slug)
    return "/photo_map/global/#{slug}.svg"
  end

  # # Posts

  def render_photo_maps_posts
    @blog.post_collection.posts.not_nil!.each do |post|
      if post.self_propelled? && post.detailed_routes && post.detailed_routes.not_nil!.size > 0
        render_photo_map_for_post(post)
      end
    end
  end

  protected def render_photo_map_for_post(post : Tremolite::Post)
    # TODO refactor post coords into something not ugly

    if post.detailed_routes.not_nil![0].route.size > 0
      Log.debug { "render_photo_maps_posts #{post.slug}" }

      # sometime I take photos from train and we want to have detailed
      # route map (big zoom) so we must remove photos taken from non route
      # places
      coord_range = PostRouteObject.array_to_coord_range(
        array: post.detailed_routes.not_nil!,
      )
      # only_types: ["hike", "bicycle", "train", "car", "air"]
      # lets accept all types for now

      autozoom_value = Map::TilesLayer.ideal_zoom(
        coord_range: coord_range.not_nil!,
        min_diagonal: 800,
        max_diagonal: 4200,
      )

      if autozoom_value
        post_map_view = PhotoMapSvgView.new(
          blog: @blog,
          url: url_photomap_for_post_big(post),
          zoom: autozoom_value.not_nil!,
          quant_size: Map::DEFAULT_POST_PHOTO_SIZE,
          post_slugs: [post.slug],
          coord_range: coord_range,
          do_not_crop_routes: true,
          render_photos_out_of_route: true,
          photo_direct_link: true,
        )
        add_photomap_for_post_big(post, post_map_view)
        write_output(post_map_view)
        Log.debug { "#{post.slug} - render_photo_maps_posts done" }
      else
        Log.warn { "#{post.slug} - autozoom_value could not calculate" }
      end
    else
      Log.debug { "#{post.slug} - no coords" }
    end
  end

  private def add_photomap_for_post_big(post, view)
    @photomaps_for_post_big ||= Hash(Tremolite::Post, PhotoMapSvgView).new
    @photomaps_for_post_big.not_nil![post] = view
  end

  private def url_photomap_for_post_big(post : Tremolite::Post)
    return "/photo_map/for_post/#{post.slug}/big.svg"
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

    voivodeship_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_voivodeship_big(voivodeship),
      zoom: Map::DEFAULT_VOIVODESHIP_ZOOM,
      quant_size: Map::DEFAULT_VOIVODESHIP_PHOTO_SIZE,
      coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    add_photomap_for_voivodeship_big(voivodeship, voivodeship_view)
    write_output(voivodeship_view)

    voivodeship_small_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_voivodeship_small(voivodeship),
      zoom: Map::DEFAULT_VOIVODESHIP_SMALL_ZOOM,
      quant_size: Map::DEFAULT_VOIVODESHIP_SMALL_PHOTO_SIZE,
      coord_range: voivodeship_coord_range,
      post_slugs: post_slugs,
    )
    add_photomap_for_voivodeship_small(voivodeship, voivodeship_small_view)
    write_output(voivodeship_small_view)
  end

  private def add_photomap_for_voivodeship_big(voivodeship, view)
    @photomaps_for_voivodeship_big ||= Hash(String, PhotoMapSvgView).new
    @photomaps_for_voivodeship_big.not_nil![voivodeship.name] = view
  end

  private def url_photomap_for_voivodeship_big(voivodeship : VoivodeshipEntity)
    return "/photo_map/for_voivodeship/#{voivodeship.slug}/big.svg"
  end

  private def add_photomap_for_voivodeship_small(voivodeship, view)
    @photomaps_for_voivodeship_small ||= Hash(String, PhotoMapSvgView).new
    @photomaps_for_voivodeship_small.not_nil![voivodeship.name] = view
  end

  private def url_photomap_for_voivodeship_small(voivodeship : VoivodeshipEntity)
    return "/photo_map/for_voivodeship/#{voivodeship.slug}/small.svg"
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

    photomap_view = PhotoMapSvgView.new(
      blog: @blog,
      url: url_photomap_for_tag(tag),
      zoom: Map::DEFAULT_TAG_ZOOM,
      quant_size: Map::DEFAULT_TAG_PHOTO_SIZE,
      photo_entities: photo_entities,
      render_routes: false,
    )
    add_photomap_for_tag(tag, photomap_view)
    write_output(photomap_view)
  end

  private def add_photomap_for_tag(tag : String, view)
    @photomaps_for_tag ||= Hash(String, PhotoMapSvgView).new
    @photomaps_for_tag.not_nil![tag] = view
  end

  private def url_photomap_for_tag(tag : String)
    return "/photo_map/for_tag/#{tag}.svg"
  end

  # # Index page

  def render_photo_maps_index
    html_view = PhotoMap::IndexView.new(
      blog: @blog,
      url: "/photo_map",
      photomaps_for_tag: @photomaps_for_tag.not_nil!,
      photomaps_for_voivodeship_big: @photomaps_for_voivodeship_big.not_nil!,
      photomaps_for_voivodeship_small: @photomaps_for_voivodeship_small.not_nil!,
      photomaps_for_post_big: @photomaps_for_post_big.not_nil!,
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
    slug = "2020-09-06-lodzkie-zakamarki-i-stare-domy"
    # slug = "2014-04-28-nadwarcianskim-szlakiem-rowerowym-oborniki-wronki"
    post = @blog.post_collection.posts.not_nil!.select do |post|
      post.slug == slug
    end.first

    render_photo_map_for_post(post)
    puts "SLEEPING"
    sleep 5
  end

  def render_photo_maps_debug_voivodeship
    @blog.data_manager.voivodeships.not_nil!.each do |voivodeship|
      next unless voivodeship.slug == "wielkopolskie"
      render_photo_map_for_voivodeship(voivodeship)
      puts "SLEEPING"
      sleep 5
    end
  end
end
