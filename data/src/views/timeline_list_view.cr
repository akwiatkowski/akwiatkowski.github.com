class TimelineList < PageView
  def initialize(@blog : Tremolite::Blog)
    @posts = @blog.post_collection.posts.select { |p| p.trip? }.as(Array(Tremolite::Post))
    @data_manager = @blog.data_manager.as(Tremolite::DataManager)
    # gather from all posts, flatten and select for only suitable for timeline
    @photo_entities = @posts.map { |p|
      p.all_photo_entities
    }.flatten.select { |p|
      # better to use only gallery capable
      # timeline capable has higher priority
      p.is_gallery
    }.as(Array(PhotoEntity))

    @image_url = @blog.data_manager.not_nil!["timeline.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["timeline.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["timeline.subtitle"].as(String)
    @url = "/timeline"
  end

  PARTS = 12 * 4 * 2
  INTERTED_QUANT = 1.0 / PARTS.to_f
  PER_ROW = 5

  getter :image_url, :title, :subtitle, :url

  def inner_html
    s = ""

    s += "<table>"

    i = 0.0
    index = 1

    while i <= 1.0
      s += part_html(i, i + INTERTED_QUANT, index)

      i += INTERTED_QUANT
      index += 1
    end

    s += "</table>"

    return s
  end

  def part_html(i_from, i_to, index)
    selected_photos = @photo_entities.select { |pe|
      pe.float_of_year >= i_from &&
      pe.float_of_year < i_to
    }.sort { |a,b|
      a.time.day_of_year <=> b.time.day_of_year
    }

    return "" if selected_photos.size == 0

    time_from = selected_photos.first.time
    time_to = selected_photos.last.time

    data = Hash(String, String).new
    data["row.size"] = selected_photos.size.to_s
    data["row.from"] = time_from.to_s("%m-%d")
    data["row.to"] = time_to.to_s("%m-%d")

    data["row.month"] = time_from.to_s("%m")
    data["row.day"] = time_from.to_s("%d")
    data["row.count"] = index.to_s

    data["row.content"] = row_content(selected_photos)

    data["colspan"] = PER_ROW.to_s

    return load_html("season_timeline/row", data)
  end

  def row_content(selected_photos)
    selected_for_row = select_photos_for_row(selected_photos)

    row_content = selected_for_row.map { |selected_photo|
      load_html("season_timeline/cell", {
        "gallery_post_image" => load_html(
          "gallery/gallery_post_image",
          selected_photo.hash_for_partial)
        }
      )
    }.join("\n")
  end

  # TODO upgrade it later
  def select_photos_for_row(selected_photos)
    selected = Array(PhotoEntity).new

    # first use `is_timeline` because some photos better describe season
    selected_photos_timeline = selected_photos.select { |pe| pe.is_timeline }

    if selected_photos_timeline.size > 0
      interval = selected_photos_timeline.size / PER_ROW
      interval = 1 if interval < 1 # just for safety

      index = 0
      while index < selected_photos_timeline.size
        # add only if within index
        if index < selected_photos_timeline.size
          selected << selected_photos_timeline[index]
        end
        index += interval

        # return if full
        return selected if selected.size == PER_ROW
      end
    end

    selected_photos_rest = selected_photos.select { |pe| pe.is_timeline == false }

    if selected_photos_rest.size > 0
      interval = selected_photos_rest.size / PER_ROW
      interval = 1 if interval < 1 # just for safety

      index = 0
      while index < selected_photos_rest.size
        # add only if within index
        if index < selected_photos_rest.size
          selected << selected_photos_rest[index]
        end
        index += interval

        # return if full
        return selected if selected.size == PER_ROW
      end
    end

    return selected
  end
end
