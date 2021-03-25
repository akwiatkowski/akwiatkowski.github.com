require "../services/day_of_week"

class PostView < BaseView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog, @post : Tremolite::Post)
    @url = @post.url.as(String)
    @validator = @blog.validator.as(Tremolite::Validator)
  end

  # not ready posts will not be added to sitemap.xml
  # this generator is part of `Tremolite` engine
  def ready
    @post.ready?
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

  def image_url
    @post.image_url
  end

  def post_article_html
    data = Hash(String, String).new
    data["gallery_url"] = @post.gallery_url
    data["content"] = @post.content_html
    # if not used should be set to blank
    data["next_post_pager"] = ""
    data["prev_post_pager"] = ""

    np = @blog.post_collection.next_to(@post)
    if np
      nd = Hash(String, String).new
      nd["post.url"] = np.url
      nd["post.title"] = np.title
      nl = load_html("post/pager_next", nd)
      data["next_post_pager"] = nl
    end

    pp = @blog.post_collection.prev_to(@post)
    if pp
      pd = Hash(String, String).new
      pd["post.url"] = pp.url
      pd["post.title"] = pp.title
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
    @post.tags.not_nil!.each do |tag|
      @blog.data_manager.not_nil!.tags.not_nil!.each do |tag_entity|
        if tag == tag_entity.slug
          links << "<a href=\"" + tag_entity.list_url + "\">" + tag_entity.name + "</a>"
        end
      end
    end
    if links.size > 0
      pd["taggable.content"] = links.join(", ")
      taggable_content = load_html("post/taggable", pd)
      data["tags_content"] = taggable_content + "<br/>"
    else
      data["tags_content"] = ""
    end

    # lands
    pd = Hash(String, String).new
    pd["taggable.name"] = "Krainy"
    pd["taggable.content"] = ""
    links = Array(String).new
    @post.lands.not_nil!.each do |land|
      @blog.data_manager.not_nil!.lands.not_nil!.each do |land_entity|
        if land == land_entity.slug
          links << "<a href=\"" + land_entity.list_url + "\">" + land_entity.name + "</a>"
        end
      end
    end
    if links.size > 0
      pd["taggable.content"] = links.join(", ")
      taggable_content = load_html("post/taggable", pd)
      data["lands_content"] = taggable_content + "<br/>"
    else
      data["lands_content"] = ""
    end

    # towns
    pd = Hash(String, String).new
    pd["taggable.name"] = "Miejscowości"
    pd["taggable.content"] = ""
    links = Array(String).new
    @post.towns.not_nil!.each do |town|
      town_entities = @blog.data_manager.not_nil!.towns.not_nil!.select { |town_entity| town == town_entity.slug }
      town_entities.each do |town_entity|
        links << "<a href=\"" + town_entity.list_url + "\">" + town_entity.name + "</a>"
      end
    end
    if links.size > 0
      pd["taggable.content"] = links.join(", ")
      taggable_content = load_html("post/taggable", pd)
      data["towns_content"] = taggable_content + "<br/>"
    else
      data["towns_content"] = ""
    end

    # voivodeships
    pd = Hash(String, String).new
    pd["taggable.name"] = "Województwa"
    pd["taggable.content"] = ""
    links = Array(String).new
    @post.towns.not_nil!.each do |voivodeship|
      @blog.data_manager.not_nil!.voivodeships.not_nil!.each do |voivodeship_entity|
        if voivodeship == voivodeship_entity.slug
          links << "<a href=\"" + voivodeship_entity.list_url + "\">" + voivodeship_entity.name + "</a>"
        end
      end
    end
    if links.size > 0
      pd["taggable.content"] = links.join(", ")
      taggable_content = load_html("post/taggable", pd)
      data["voivodeships_content"] = taggable_content + "<br/>"
    else
      data["voivodeships_content"] = ""
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
    related_posts = @post.related_posts(@blog)
    if related_posts.size > 0
      pd = Hash(String, String).new

      related_content = ""

      # all related post items
      related_posts.each do |related_post|
        rpd = Hash(String, String).new
        rpd["post.url"] = related_post.url
        rpd["post.title"] = related_post.title
        rpd["post.date"] = related_post.date
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
