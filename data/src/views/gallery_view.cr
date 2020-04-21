# TODO refactor to abstract GalleryAbstractView
class GalleryView < WidePageView
  Log = ::Log.for(self)
  
  def initialize(@blog : Tremolite::Blog)
    @all_posts = @blog.post_collection.posts.as(Array(Tremolite::Post))
    # only w/o "nogallery" flag and only trips
    @posts = @all_posts.select { |p|
      p.trip?
    }.as(Array(Tremolite::Post))
    @data_manager = @blog.data_manager.not_nil!.as(Tremolite::DataManager)

    @image_url = @blog.data_manager.not_nil!["gallery.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["gallery.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["gallery.subtitle"].as(String)

    @url = "/gallery"
  end

  getter :image_url, :title, :subtitle, :year, :url

  def inner_html
    s = ""

    sorted_by_time = @posts.sort { |a, b| a.time <=> b.time }
    if sorted_by_time.size > 0
      time_from = sorted_by_time.first.time
      time_to = sorted_by_time.last.time

      t = time_to.at_end_of_month

      # month loop
      while t > time_from
        # month header
        data = Hash(String, String).new
        data["month_string"] = t.to_s("%Y-%m")
        month_header = load_html("gallery/gallery_month_separator", data)
        # some processing
        posts_in_month = @posts.select { |p| p.time >= t.at_beginning_of_month && p.time < t.at_end_of_month }.sort { |a, b| b.time <=> a.time }
        # not add empty months
        s += month_header if posts_in_month.size > 0

        # content
        if posts_in_month.size > 0
          posts_in_month.each do |post|
            s += post_images(post)
          end
        end

        # to be sure
        t = t.at_beginning_of_month - 1.month
      end
    end

    return s
  end

  def post_images(post)
    s = ""

    post.published_photo_entities.each do |photo_entity|
      if photo_entity.is_gallery
        s += load_html("gallery/gallery_post_image", photo_entity.hash_for_partial)
      end
    end

    return s
  end
end
