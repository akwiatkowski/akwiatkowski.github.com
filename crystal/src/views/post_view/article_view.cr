require "../../services/day_of_week"

module PostView
  class ArticleView < BaseView
    Log = ::Log.for(self)

    def initialize(
      @context : RenderContext,
      @post : Tremolite::Post,
      @hide_not_finished : Bool = false,
    )
      @url = @post.url.as(String)
      @validator = @context.not_nil!.validator.as(Tremolite::Validator) # TODO: not_nil! is weird here
    end

    # not ready posts will not be added to sitemap.xml
    # this generator is part of `Tremolite` engine
    def ready
      @post.ready?
    end

    def add_to_sitemap?
      ready
    end

    def title
      @post.title
    end

    def content
      post_header_html +
        post_article_html
    end

    def post_header_html
      data = Hash(String, String).new
      data["post.image_url"] = image_url
      data["post.image.position"] = @post.image_position.to_s
      data["post.title"] = @post.title
      data["post.subtitle"] = @post.subtitle
      data["post.author"] = @post.author
      data["post.date"] = @post.date
      data["post.date.day_of_week"] = @post.time.day_of_week_polish
      return load_html("post/header", data)
    end

    # only Post view can process more complicated to allow
    # use custom header image (from different post/article)
    def image_url
      return @post.head_photo_entity.not_nil!.full_image_src
    end

    def post_article_html
      data = Hash(String, String).new
      data["gallery_url"] = @post.gallery_url
      data["content"] = @post.content_html
      # if not used should be set to blank
      data["next_post_pager"] = ""
      data["prev_post_pager"] = ""

      np = context.next_post(@post)
      if np
        nd = Hash(String, String).new
        nd["post.url"] = np.url
        nd["post.title"] = np.title
        nd["post.image"] = np.head_photo_entity.not_nil!.thumbnail_image_src
        nd["post.image.avif"] = np.head_photo_entity.not_nil!.thumbnail_avif_src
        nl = load_html("post/pager_next", nd)
        data["next_post_pager"] = nl
      end

      pp = context.prev_post(@post)
      if pp
        pd = Hash(String, String).new
        pd["post.url"] = pp.url
        pd["post.title"] = pp.title
        pd["post.image"] = pp.head_photo_entity.not_nil!.thumbnail_image_src
        pd["post.image.avif"] = pp.head_photo_entity.not_nil!.thumbnail_avif_src
        pl = load_html("post/pager_prev", pd)
        data["prev_post_pager"] = pl
      end

      gd = Hash(String, String).new
      gd["gallery.url"] = @post.gallery_url
      gl = load_html("post/pager_gallery", gd)
      data["gallery_pager"] = gl

      # tags
      pd = Hash(String, String).new
      pd["taggable.name"] = "Tagi"
      pd["taggable.content"] = ""
      links = Array(String).new
      @post.tag_slugs.each do |tag|
        context.tags.each do |tag_entity|
          if tag == tag_entity.slug
            links << "<a href=\"" + tag_entity.view_url + "\">" + tag_entity.name + "</a>"
          end
        end
      end
      if links.size > 0
        pd["taggable.content"] = links.join(", ")
        data["tags_content"] = load_html("post/taggable", pd)
      else
        data["tags_content"] = ""
      end

      # lands (meso regions) - using AreaEntity system
      land_entities = @post.meso_region_entities
      if land_entities.size > 0
        pd = Hash(String, String).new
        pd["taggable.name"] = "Krainy"
        links = land_entities.map { |entity| "<a href=\"#{entity.view_url}\">#{entity.name}</a>" }
        pd["taggable.content"] = links.join(", ")
        data["lands_content"] = load_html("post/taggable", pd)
      else
        data["lands_content"] = ""
      end

      # towns - using AreaEntity system
      town_entities = @post.town_entities
      if town_entities.size > 0
        pd = Hash(String, String).new
        pd["taggable.name"] = "Miejscowości"
        links = town_entities.map { |entity| "<a href=\"#{entity.view_url}\">#{entity.name}</a>" }
        pd["taggable.content"] = links.join(", ")
        data["towns_content"] = load_html("post/taggable", pd)
      else
        data["towns_content"] = ""
      end

      # voivodeships - using AreaEntity system
      voivodeship_entities = @post.voivodeship_entities
      if voivodeship_entities.size > 0
        pd = Hash(String, String).new
        pd["taggable.name"] = "Województwa"
        links = voivodeship_entities.map { |entity| "<a href=\"#{entity.view_url}\">#{entity.name}</a>" }
        pd["taggable.content"] = links.join(", ")
        data["voivodeships_content"] = load_html("post/taggable", pd)
      else
        data["voivodeships_content"] = ""
      end

      # foreign (external) areas - using AreaEntity system + country fallback
      foreign_entities = @post.foreign_entities
      foreign_slugs = @post.foreign_slugs
      # Find slugs that didn't resolve to entities (country-only slugs)
      entity_slugs = foreign_entities.map(&.slug)
      unresolved_slugs = foreign_slugs.reject { |s| entity_slugs.includes?(s) }

      # Build display items: links for entities, plain text for countries
      items = [] of String
      foreign_entities.each { |entity| items << "<a href=\"#{entity.view_url}\">#{entity.name}</a>" }
      unresolved_slugs.each do |slug|
        country_name = context.country_name(slug)
        items << country_name if country_name
      end

      if items.size > 0
        pd = Hash(String, String).new
        pd["taggable.name"] = "Zagranica"
        pd["taggable.content"] = items.join(", ")
        data["foreign_content"] = load_html("post/taggable", pd)
      else
        data["foreign_content"] = ""
      end

      # pois
      if @post.pois.not_nil!.size > 0
        pd = Hash(String, String).new
        pd["pois_list"] = @post.pois.not_nil!.map { |p| p.wrapped_link }.join("")
        pois_container = load_html("post/pois", pd)
        data["pois_container"] = pois_container
      else
        data["pois_container"] = ""
      end

      # related
      related_posts = @post.related_posts(context: context)
      if related_posts.size > 0
        pd = Hash(String, String).new

        related_content = ""

        # all related post items
        related_posts.each do |related_post|
          rpd = Hash(String, String).new
          rpd["post.url"] = related_post.url
          rpd["post.title"] = related_post.title
          rpd["post.date"] = related_post.date
          rpd["post.thumbnail"] = related_post.head_photo_entity.not_nil!.grid_image_src
          rpd["post.thumbnail.avif"] = related_post.head_photo_entity.not_nil!.grid_avif_src
          related_content += load_html("post/related_post", rpd)
        end

        pd["related.content"] = related_content
        related_container = load_html("post/related_list", pd)
        data["related_container"] = related_container
      else
        data["related_container"] = ""
      end

      # todo notice and finished_at
      data["finished_at_container"] = ""
      if @post.ready?
        data["todo"] = ""

        if @post.finished_at
          finished_at = @post.finished_at.not_nil!
          finished_at_days = (finished_at.at_beginning_of_day - @post.time.at_beginning_of_day).days
          fad = Hash(String, String).new
          fad["finished_at.date"] = finished_at.to_s("%Y-%m-%d")
          fad["finished_at.days"] = finished_at_days.to_s
          data["finished_at_container"] = load_html("post/finished_at", fad)
        end
      else
        data["todo"] = load_html("post/todo")
      end

      # small photo_map for post
      path_for_svg = context.photo_map_dictionary.get_small_photo_map_for_post(@post)
      if path_for_svg
        zoom = @post.default_map_zoom || 11
        coord_range = @post.routes_coord_range.not_nil!
        center = coord_range.center

        ump_map_link = "https://mapa.ump.waw.pl/ump-www/?zoom=#{zoom}&lat=#{center[:lat]}&lon=#{center[:lon]}"
        osm_map_link = "https://www.openstreetmap.org/#map=#{zoom}/#{center[:lat]}/#{center[:lon]}"
        google_map_link = "https://www.google.pl/maps/@#{center[:lat]},#{center[:lon]},#{zoom}z"
        mapy_cz_link = "https://en.mapy.cz/zakladni?x=#{center[:lon]}&y=#{center[:lat]}&z=#{zoom}"
        distance = (@post.distance || "--").to_s

        route_info = String.build do |s|
          s << %(<div class="post-route-stats">)
          if @post.bicycle?
            s << %(<span class="activity-badge">🚴 rowerem</span>)
          elsif @post.hike? && (@post.distance || 0) > 0
            s << %(<span class="activity-badge">🥾 pieszo</span>)
          elsif @post.train?
            s << %(<span class="activity-badge">🚆 pociągiem</span>)
          elsif @post.bus?
            s << %(<span class="activity-badge">🚌 autobusem</span>)
          elsif @post.car?
            s << %(<span class="activity-badge">🚗 samochodem</span>)
          elsif @post.walk?
            s << %(<span class="activity-badge">🚶 spacer</span>)
          end
          if @post.distance
            s << %(<span>📍 #{@post.distance.not_nil!.to_i} km</span>)
          end
          if @post.time_spent
            s << %(<span>⏱️ #{@post.time_spent.not_nil!.to_i} h</span>)
          end
          if @post.temperature
            temp = @post.temperature.not_nil!.to_i
            temp_icon = if temp <= 0
                          "❄️"
                        elsif temp <= 15
                          "🌤️"
                        elsif temp <= 25
                          "☀️"
                        else
                          "🔥"
                        end
            s << %(<span>#{temp_icon} #{temp} &deg;C</span>)
          end
          s << %(</div>)
        end

        data["svg_map"] = load_html(
          "post/svg_map",
          {
            "svg_path"        => path_for_svg,
            "ump_map_link"    => ump_map_link,
            "osm_map_link"    => osm_map_link,
            "google_map_link" => google_map_link,
            "mapy_cz_link"    => mapy_cz_link,
            "route_info"      => route_info,
          }
        )
      else
        data["svg_map"] = ""
      end

      # for released version I'd like no to send not finished, draft content
      if @hide_not_finished == true && !ready
        data["content"] = ""
      end

      return load_html("post/article", data)
    end

    # overriden here
    def page_desc
      return @post.desc.not_nil!
    end

    # overriden here
    def meta_keywords_string
      return @post.keywords.not_nil!.join(", ").as(String)
    end
  end
end
