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
      str << "<th>Akt.</th>\n"
      str << "<th>Zmiana</th>\n"
      str << "<th>%</th>\n"

      str << "<th>Poprz</th>\n"
      str << "<th>Akt.</th>\n"
      str << "<th>Zmiana</th>\n"
      str << "<th>%</th>\n"

      str << "</tr>\n"


      data.each do |record|
        str << "<tr>\n"

        str << "<td>#{record[:month].to_s("%Y-%m")}</td>\n"

        # distance, last year
        opacity_style = opacity_style_string(
          value: record[:distance_last_year],
          max: 400,
          color_string: "70,255,70"
        )
        str << "<td style='#{opacity_style}' >"
        if record[:distance_last_year]
          str << "#{record[:distance_last_year]}km"
        end
        str << "</td>\n"

        # distance, current year
        opacity_style = opacity_style_string(
          value: record[:distance],
          max: 400,
          color_string: "0,255,0"
        )
        str << "<td style='#{opacity_style}' >"
        if record[:distance]
          str << "#{record[:distance]}km"
        end
        str << "</td>\n"

        # distance, delta
        opacity_style = ""
        if record[:distance_change]
          if record[:distance_change].not_nil! > 0
            opacity_style = opacity_style_string(
              value: record[:distance_change],
              max: 400,
              color_string: "0,128,255"
            )
          else
            opacity_style = opacity_style_string(
              value: record[:distance_change],
              max: -400,
              color_string: "255,0,0"
            )
          end
        end

        str << "<td style='#{opacity_style}' >"
        if record[:distance_change]
          str << "#{record[:distance_change]}km"
        end
        str << "</td>\n"

        # distance delta, percentage
        opacity_style = ""
        if record[:distance_change_percent]
          if record[:distance_change_percent].not_nil! > 0
            opacity_style = opacity_style_string(
              value: record[:distance_change_percent],
              max: 100,
              color_string: "0,128,255"
            )
          else
            opacity_style = opacity_style_string(
              value: record[:distance_change_percent],
              max: -100,
              color_string: "255,0,0"
            )
          end
        end

        str << "<td style='#{opacity_style}' >"
        if record[:distance_change_percent]
          str << "#{record[:distance_change_percent]}%"
        end
        str << "</td>\n"


        # time_spent, last year
        opacity_style = opacity_style_string(
          value: record[:time_spent_last_year],
          max: 50,
          color_string: "255,255,0"
        )
        str << "<td style='#{opacity_style}' >"
        if record[:time_spent_last_year]
          str << "#{record[:time_spent_last_year]}h"
        end
        str << "</td>\n"

        # distance, current year
        opacity_style = opacity_style_string(
          value: record[:time_spent],
          max: 50,
          color_string: "255,255,0"
        )
        str << "<td style='#{opacity_style}' >"
        if record[:time_spent]
          str << "#{record[:time_spent]}h"
        end
        str << "</td>\n"


        # time_spent, delta
        opacity_style = ""
        if record[:time_spent_change]
          if record[:time_spent_change].not_nil! > 0
            opacity_style = opacity_style_string(
              value: record[:time_spent_change],
              max: 40,
              color_string: "0,128,255"
            )
          else
            opacity_style = opacity_style_string(
              value: record[:time_spent_change],
              max: -40,
              color_string: "255,0,0"
            )
          end
        end

        str << "<td style='#{opacity_style}' >"
        if record[:time_spent_change]
          str << "#{record[:time_spent_change]}km"
        end
        str << "</td>\n"

        # distance delta, percentage
        opacity_style = ""
        if record[:time_spent_change_percent]
          if record[:time_spent_change_percent].not_nil! > 0
            opacity_style = opacity_style_string(
              value: record[:time_spent_change_percent],
              max: 100,
              color_string: "0,128,255"
            )
          else
            opacity_style = opacity_style_string(
              value: record[:time_spent_change_percent],
              max: -100,
              color_string: "255,0,0"
            )
          end
        end

        str << "<td style='#{opacity_style}' >"
        if record[:time_spent_change_percent]
          str << "#{record[:time_spent_change_percent]}%"
        end
        str << "</td>\n"

        # end of row
        str << "</tr>\n"
      end

      str << "</table>\n"
    end


  end
end
