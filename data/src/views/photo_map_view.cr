require "../services/map/base"

class PhotoMapView < WidePageView
  def initialize(
    @blog : Tremolite::Blog,
    @url : String,
    # size of small quant - one image per quant
    @quant_width = 0.10,
    # pixel width of @quant_width
    @quant_css_width = 100,
    # append towns on map
    @append_towns = true
  )
  end

  # main params of this page
  def title
    @blog.data_manager.not_nil!["map.title"]
  end

  def image_url
    @image_url = @blog.data_manager.not_nil!["map.backgrounds"].as(String)
  end

  # w/o header image
  def content
    return inner_html
  end

  # because of absolute positioning we don't want copyright footer here
  def footer
    return ""
  end

  def inner_html
    m = Map::Base.new(
      blog: @blog,
    )

    return m.to_s

    #
    # content_string = ""
    #
    # # background tiles
    # content_string += map_tiles_svg
    #
    # # photos
    # # photo_array = process_photos
    # #
    # # # add photos
    # # photo_array.each do |ph|
    # #   content_string += load_html(
    # #     "photo_map/photo",
    # #     convert_photo_map_set_to_html_hash(ph)
    # #   )
    # # end
    #
    # # add towns if enabled
    # if @append_towns
    #   @towns.each do |town|
    #     content_string += load_html(
    #       "photo_map/town",
    #       convert_town_to_html_hash(town)
    #     )
    #   end
    # end
    #
    # # all posts routes as svg
    # # TODO temporary disabled because it block photos and not look good enough
    # #content_string += posts_routes_svg
    #
    # data = Hash(String, String).new
    # data["photos"] = content_string
    # return load_html("photo_map/main", data)
  end
end
