require "./exif_stat_service"
require "./exif_lens_coverage"

class ExifStatHelper
  def initialize(
    @photos : Array(PhotoEntity) = Array(PhotoEntity).new,
    @posts : Array(Tremolite::Post) = Array(Tremolite::Post).new
  )
    @service = ExifStatService.new
  end

  # generate html tables from data
  def generate_table_for_array(
    title_array,
    array
  )
    s = ""
    s += "<table class='table exif-stats-table'>\n"
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
          s += "<td>"
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
        array_h[title_h[:key]]?
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

  # process, incremend data for overall/lens/camera
  def make_it_so
    @service.append(@photos)
    @service.make_it_so
  end

  # to render Hash(String -> ExifStatStruct) table for lens or camera stats
  private def render_hash_based_count_table(
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
      time_from = stat_structure.time_from
      time_from = time_from.to_s("%Y-%m-%d") if time_from
      time_to = stat_structure.time_to
      time_to = time_to.to_s("%Y-%m-%d") if time_to

      {
        lens:          lens,
        avg_per_month: stat_structure.smart_avg_per_month || 0,
        from:          time_from,
        to:            time_to,
      }
    end.sort do |a, b|
      b[:avg_per_month].to_i <=> a[:avg_per_month].to_i
    end

    titles = [
      {title: "Obiektyw", key: :lens},
      {title: "Zdj. na miesiąc", key: :avg_per_month},
      {title: "Od", key: :from},
      {title: "Do", key: :to},
    ]

    return generate_table_for_array_of_hash(
      title_ah: titles,
      array_ah: array
    )
  end

  def html_stats_focal_lengths_total : String
    # not render not used focal ranges
    focal_stats = @service.focal_range_stats_overall.select do |fs|
      fs[:count] > 0
    end

    title_array = ["Ogniskowa [mm]"] + focal_stats.map do |fs|
      "#{fs[:from]}-#{fs[:to]}"
    end

    array = [nil] + focal_stats.map do |fs|
      fs[:count]
    end

    return generate_table_for_array(
      title_array: title_array,
      array: [array]
    )
  end

  def html_stats_focal_lengths_by_lens(
    only_zoom : Bool = false
  ) : String
    lenses = @service.stats_by_lens.keys.sort.as(Array(String))

    if only_zoom
      lenses = lenses.select do |lens|
        @service.stats_by_lens[lens].is_zoom
      end
    end

    # if no zoom lenses return empty string
    return "" if lenses.size == 0

    # helper variable used for sorting strings
    focal_hash = Hash(String, String).new
    # helper int hash to speed up sorting
    focal_int = Hash(Int32, Int32).new
    # last row is summary
    summary_hash = Hash(String, Int32).new

    array_ah = lenses.map do |lens|
      # get stats struct
      stats_struct = @service.stats_by_lens[lens]
      focal_stats = @service.process_focal_hash_to_array_stats(
        stats_struct.count_by_focal35
      )

      row_hash = focal_stats.map do |fs|
        if fs[:count] > 0
          # key is focal range from, value is string key and title
          focal_hash[fs[:from].to_s] ||= "#{fs[:from]}-#{fs[:to]}"
          # to speed up sorting
          focal_int[fs[:from]] ||= 1

          # add to summary
          summary_hash[fs[:from].to_s] ||= 0
          summary_hash[fs[:from].to_s] += fs[:count]

          # will be used to render table
          [fs[:from].to_s, fs[:count].to_s]
        else
          nil
        end
      end.compact.to_h

      # add lens name
      row_hash["lens"] = lens

      row_hash
    end

    # add summary only there is more than 1 lenses
    if lenses.size > 1
      summary_hash_string = summary_hash.to_a.map do |sh|
        [sh[0], sh[1].to_s]
      end.to_h
      summary_hash_string["lens"] = "Suma"
      array_ah << summary_hash_string
    end

    # titles from helper hash
    # first row is "lens"
    title_ah = [
      {
        key:   "lens",
        title: "Obiektyw",
      },
    ] + focal_int.keys.sort.map do |from_focal|
      {
        key:   from_focal.to_s,
        title: focal_hash[from_focal.to_s],
      }
    end

    return generate_table_for_array_of_hash(
      title_ah: title_ah,
      array_ah: array_ah
    )
  end

  def html_stats_focal_lengths_by_month : String
    months_and_focals = @service.stats_overall.count_by_month_and_focal35
    months = months_and_focals.keys.sort

    # if no zoom lenses return empty string
    return "" if months.size == 0

    # helper variable used for sorting strings
    focal_hash = Hash(String, String).new
    # helper int hash to speed up sorting
    focal_int = Hash(Int32, Int32).new
    # last row is summary
    summary_hash = Hash(String, Int32).new

    array_ah = months.map do |month|
      # get stats struct
      focal_stats = @service.process_focal_hash_to_array_stats(
        months_and_focals[month]
      )

      row_hash = focal_stats.map do |fs|
        if fs[:count] > 0
          # key is focal range from, value is string key and title
          focal_hash[fs[:from].to_s] ||= "#{fs[:from]}-#{fs[:to]}"
          # to speed up sorting
          focal_int[fs[:from]] ||= 1

          # add to summary
          summary_hash[fs[:from].to_s] ||= 0
          summary_hash[fs[:from].to_s] += fs[:count]

          # will be used to render table
          [fs[:from].to_s, fs[:count].to_s]
        else
          nil
        end
      end.compact.to_h

      # add lens name
      row_hash["month"] = month.to_s("%Y&#8722;%m")

      row_hash
    end

    # add summary only there is more than 1 months
    if months.size > 1
      summary_hash_string = summary_hash.to_a.map do |sh|
        [sh[0], sh[1].to_s]
      end.to_h
      summary_hash_string["month"] = "Suma"
      array_ah << summary_hash_string
    end

    # titles from helper hash
    # first row is "lens"
    title_ah = [
      {
        key:   "month",
        title: "Miesiąc",
      },
    ] + focal_int.keys.sort.map do |from_focal|
      {
        key:   from_focal.to_s,
        title: focal_hash[from_focal.to_s],
      }
    end

    return generate_table_for_array_of_hash(
      title_ah: title_ah,
      array_ah: array_ah
    )
  end

  # render table which will calculate how lens would be useful to me
  # old one, still available
  def html_stats_lens_focal_coverage : String
    exif_coverage = ExifStat::ExifLensCoverage.new(
      stats_struct: @service.stats_overall
    )

    array_ah = exif_coverage.data_for_lens_focal_coverage

    title_ah = [
      {key: :name, title: "Obiektyw"},
      {key: :count, title: "Ilość zdjęć"},
      {key: :percentage, title: "Procenty"},
      {key: :total_weight, title: "Waga"},
      {key: :perc_per_weight, title: "%/waga"},
    ]

    return generate_table_for_array_of_hash(
      title_ah: title_ah,
      array_ah: array_ah
    )
  end

  # render table which will calculate how lens would be useful to me
  # new one
  def html_stats_photo_kit_coverage : String
    exif_coverage = ExifStat::ExifLensCoverage.new(
      stats_struct: @service.stats_overall
    )

    photo_kit_array = exif_coverage.photo_kit_coverage_data

    array_ah = Array(NamedTuple(
      name: String | Nil,
      other_name: String | Nil,
      count: Int32,
      additional_count: Int32 | Nil,
      weight: Int32,
      additional_weight: Int32 | Nil,
      percentage: Int32,
      additional_percent: Int32 | Nil,
      perc_per_weight: Int32,
    )).new

    title_ah = [
      {key: :name, title: "Obiektyw"},
      {key: :other_name, title: "Dodatkowy ob."},
      {key: :count, title: "Ilość"},
      {key: :additional_count, title: "+"},
      {key: :weight, title: "Waga"},
      {key: :additional_weight, title: "+"},
      {key: :percentage, title: "%"},
      {key: :additional_percent, title: "+"},
      {key: :perc_per_weight, title: "%/waga"},
    ]

    photo_kit_array.each do |photo_kit|
      array_ah << {
        name:               photo_kit[:lens][:name],
        other_name:         nil,
        count:              photo_kit[:lens][:count],
        additional_count:   nil,
        weight:             photo_kit[:lens][:weight],
        additional_weight:  nil,
        percentage:         photo_kit[:lens][:percentage],
        additional_percent: nil,
        perc_per_weight:    photo_kit[:lens][:perc_per_weight],
      }

      photo_kit[:other_useful_lenses].as(Array).each do |other_lens|
        array_ah << {
          name:               nil, # photo_kit[:lens][:name],
          other_name:         other_lens[:name],
          count:              other_lens[:count] + photo_kit[:lens][:count],
          additional_count:   other_lens[:count],
          weight:             other_lens[:weight] + photo_kit[:lens][:weight],
          additional_weight:  other_lens[:weight],
          percentage:         other_lens[:percentage],
          additional_percent: other_lens[:additional_percentage],
          perc_per_weight:    other_lens[:total_perc_per_weight],
        }
      end
    end

    return generate_table_for_array_of_hash(
      title_ah: title_ah,
      array_ah: array_ah
    )
  end

  # stats at post gallery page
  def render_post_gallery_stats
    s = ""

    s += html_stats_count_by_camera
    s += html_stats_focal_lengths_by_lens

    return s
  end

  # stats at post gallery-stats page
  # page with only stats, no photos
  def render_post_gallery_detailed_stats
    s = ""

    s += html_stats_count_by_camera
    s += html_stats_focal_lengths_by_lens
    s += html_stats_photo_kit_coverage

    return s
  end

  def render_overall_stats
    s = ""

    s += html_stats_lens_usage
    s += html_stats_count_by_camera
    s += html_stats_focal_lengths_by_lens
    s += html_stats_focal_lengths_by_month
    s += html_stats_photo_kit_coverage

    return s
  end
end
