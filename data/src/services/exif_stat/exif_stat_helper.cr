require "./exif_stat_service"

class ExifStatHelper
  def initialize(
    @photos : Array(PhotoEntity) = Array(PhotoEntity).new,
    @posts : Array(Tremolite::Post) = Array(Tremolite::Post).new
  )
    @service = ExifStatService.new
  end

  def generate_table_for_array(
    title_array,
    array
  )
    s = ""
    s += "<table class='table'>\n"
    s += "<thead>\n"

    # header title
    s += "<tr>"
    title_array.each do |title|
      s += "<th>#{title}</th>"
    end
    s += "</tr>\n"
    s += "</thead>\n"

    # content
    s += "<tbody>\n"
    array.each do |array_row|
      s += "<tr>"
      array_row.each do |cell|
        if cell
          s += "<td>#{cell}</td>"
        else
          s += "<td\>"
        end
      end
      s += "</tr>\n"
    end

    s += "</tbody>\n"
    s += "</table>"

    return s
  end

  def generate_table_for_array_of_hash(
    title_ah : Array,
    array_ah : Array
  )
    title_array = Array(String).new
    title_ah.each do |title_h|
      title_array << title_h[:title]
    end

    array = array_ah.map do |array_h|
      title_ah.map do |title_h|
        array_h[title_h[:key]]
      end
    end

    return generate_table_for_array(
      title_array: title_array,
      array: array
    )
  end

  def generate_table_for_hash_string_integer(
    hash,
    title : String
  ) : String
    s = ""

    # descending order
    sorted_keys = hash.keys.sort { |a, b| hash[a].to_i <=> hash[b].to_i }.reverse

    return generate_table_for_array(
      title_array: [title, "Ilość"],
      array: sorted_keys.map { |key| [key, hash[key]] }
    )
  end

  def make_it_so
    @service.append(@photos)
    @service.make_it_so
  end

  def render_hash_based_count_table(
    hash : Hash(String, ExifStatStruct),
    title : String
  ) : String
    if hash.keys.size > 0
      processed_hash = hash.keys.map do |key|
        [
          key,
          hash[key].count,
        ]
      end.to_h

      return generate_table_for_hash_string_integer(
        hash: processed_hash,
        title: title
      )
    else
      return ""
    end
  end

  def html_stats_count_by_camera : String
    return render_hash_based_count_table(
      hash: @service.stats_by_camera,
      title: "Aparat"
    )
  end

  def html_stats_count_by_lens : String
    return render_hash_based_count_table(
      hash: @service.stats_by_lens,
      title: "Obiektyw"
    )
  end

  def html_stats_lens_usage : String
    array = @service.stats_by_lens.map do |lens, stat_structure|
      {
        lens:          lens,
        avg_per_month: stat_structure.smart_avg_per_month || 0,
      }
    end.sort do |a, b|
      b[:avg_per_month].to_i <=> a[:avg_per_month].to_i
    end

    titles = [
      {title: "Obiektyw", key: :lens},
      {title: "Zdj. na miesiąc", key: :avg_per_month},
    ]

    return generate_table_for_array_of_hash(
      title_ah: titles,
      array_ah: array
    )
  end

  def render_basic_stats
    s = ""

    s += html_stats_count_by_lens
    s += html_stats_count_by_camera

    return s
  end

  def render_lens_usage
    s = ""

    s += html_stats_lens_usage

    return s
  end

  def to_html
    s = ""

    # if @count_by_lens.keys.size > 0
    #   s += generate_table_for_hash(
    #     hash: @count_by_lens,
    #     title: "Obiektywy"
    #   )
    #
    #   # additional table, how often lens is used
    #   if @multiple_day_stats
    #     s += lens_how_often_used_table
    #   end
    # end
    #
    # if @count_by_camera.keys.size > 0
    #
    # end
    #
    # # by focal length
    # if @count_by_focal35.keys.size > 0
    #   titles = Array(String).new
    #   values = Array(Int32 | Nil).new
    #
    #   if @count_by_focal35_lower > 0
    #     titles << "&lt; #{MIN_FOCAL}"
    #     values << @count_by_focal35_lower
    #   end
    #
    #   @count_by_focal35.keys.sort.each do |focal_range_begin|
    #     focal_range = NORMALIZATION_RANGES.select{|fr| fr.begin == focal_range_begin}.first
    #     title = FOCAL_KEY_PROC.call(focal_range)
    #     value = @count_by_focal35[focal_range_begin]
    #
    #     titles << title
    #     values << value
    #   end
    #
    #   if @count_by_focal35_higher > 0
    #     titles << "&gt; #{MAX_FOCAL}"
    #     values << @count_by_focal35_higher
    #   end
    #
    #   if titles.size > 0
    #     focal_ranges_html = generate_table_for_array(
    #       array: [ [nil] + values],
    #       title_array: ["Ogniskowa [mm]"] + titles
    #     )
    #
    #     s += focal_ranges_html
    #   end
    # end

    return s
  end
end
