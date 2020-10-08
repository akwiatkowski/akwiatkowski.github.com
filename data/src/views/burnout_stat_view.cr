require "../services/burnout_stat"

class BurnoutStatView < WidePageView
  Log = ::Log.for(self)

  def initialize(@blog : Tremolite::Blog)
    @stat = BurnoutStat.new(blog: @blog)
    @url = "/burnout"
  end

  def opacity_style_string(
    value = 0,
    max = 100,
    color_string = "50,255,50"
  )
    return "" if value.nil?

    opacity = value.to_f / max.to_f
    opacity = 1.0 if opacity > 1.0
    opacity = 0.0 if opacity < 0.0

    return "background-color: rgba(#{color_string},#{opacity});"
  end

  # def render_cell(
  #   record_value = nil,
  #   positive_max = 100,
  #   positive_color_string = "0,255,0", # "0,192,255"
  #   negative_max = -100,
  #   negative_color_string = "255,0,0",
  #   unit_name = ""

  def render_cell(
    record_value = nil,
    positive_max = 100,
    positive_color_string = "0,255,0", # "0,192,255"
    negative_max = -100,
    negative_color_string = "255,0,0",
    unit_name = ""
  )
    opacity_style = ""
    if record_value
      if record_value.not_nil! > 0
        opacity_style = opacity_style_string(
          value: record_value,
          max: positive_max,
          color_string: positive_color_string,
        )
      else
        opacity_style = opacity_style_string(
          value: record_value,
          max: negative_max,
          color_string: negative_color_string,
        )
      end
    end

    return String.build do |str|
      str << "<td style='#{opacity_style}' >"
      if record_value
        str << "#{record_value}#{unit_name}"
      end
      str << "</td>\n"
    end
  end

  def inner_html
    data = @stat.make_it_so

    return String.build do |str|
      str << "<table>\n"

      str << "<tr>\n"
      str << "<th></th>\n"
      str << "<th colspan='4'>Dystans</th>\n"
      str << "<th colspan='4'>Czas</th>\n"
      str << "</tr>\n"

      str << "<tr>\n"
      str << "<th>Miesiąc</th>\n"

      str << "<th>Poprz</th>\n"
      str << "<th>Śr.</th>\n"
      str << "<th>Akt.</th>\n"
      str << "<th>Zmiana</th>\n"

      str << "<th>Poprz</th>\n"
      str << "<th>Śr.</th>\n"
      str << "<th>Akt.</th>\n"
      str << "<th>Zmiana</th>\n"

      str << "</tr>\n"

      data.reverse.each do |record|
        str << "<tr>\n"

        str << "<td>#{record[:month].to_s("%Y-%m")}</td>\n"

        # distance, last year
        str << render_cell(
          record_value: record[:distance_last_year],
          positive_max: 400,
          positive_color_string: "70,255,70",
          negative_max: -100,
          negative_color_string: "255,255,255",
          unit_name: "km",
        )

        # distance, avg
        str << render_cell(
          record_value: record[:distance_avg],
          positive_max: 400,
          positive_color_string: "70,255,70",
          negative_max: -100,
          negative_color_string: "255,255,255",
          unit_name: "km",
        )

        # distance, current year
        str << render_cell(
          record_value: record[:distance],
          positive_max: 400,
          positive_color_string: "0,255,0",
          negative_max: -100,
          negative_color_string: "255,255,255",
          unit_name: "km",
        )

        # distance, delta
        str << render_cell(
          record_value: record[:distance_avg_change],
          positive_max: 400,
          positive_color_string: "0,128,255",
          negative_max: -400,
          negative_color_string: "255,0,0",
          unit_name: "km",
        )

        # # distance delta, percentage
        # str << render_cell(
        #   record_value: record[:distance_change_percent],
        #   positive_max: 100,
        #   positive_color_string: "0,128,255",
        #   negative_max: -100,
        #   negative_color_string: "255,0,0",
        #   unit_name: "%",
        # )

        # time_spent, last year
        str << render_cell(
          record_value: record[:time_spent_last_year],
          positive_max: 50,
          positive_color_string: "255,255,0",
          negative_max: -50,
          negative_color_string: "255,255,255",
          unit_name: "h",
        )

        # time_spent, average
        str << render_cell(
          record_value: record[:time_spent_avg],
          positive_max: 50,
          positive_color_string: "255,255,0",
          negative_max: -50,
          negative_color_string: "255,255,255",
          unit_name: "h",
        )

        # time_spent, current year
        str << render_cell(
          record_value: record[:time_spent],
          positive_max: 50,
          positive_color_string: "255,255,0",
          negative_max: -50,
          negative_color_string: "255,255,255",
          unit_name: "h",
        )

        # time_spent, delta
        str << render_cell(
          record_value: record[:time_spent_avg_change],
          positive_max: 40,
          positive_color_string: "0,128,255",
          negative_max: -40,
          negative_color_string: "255,0,0",
          unit_name: "h",
        )

        # # distance delta, percentage
        # opacity_style = ""
        # str << render_cell(
        #   record_value: record[:time_spent_change_percent],
        #   positive_max: 100,
        #   positive_color_string: "0,128,255",
        #   negative_max: -100,
        #   negative_color_string: "255,0,0",
        #   unit_name: "%",
        # )

        # end of row
        str << "</tr>\n"
      end

      str << "</table>\n"
    end


  end
end
