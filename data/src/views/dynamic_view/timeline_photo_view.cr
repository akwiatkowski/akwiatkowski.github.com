require "../wide_page_view"

module DynamicView
  class TimelinePhotoView < WiderPageView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog)
      @posts = @blog.post_collection.posts.select { |p| p.trip? }.as(Array(Tremolite::Post))
      @data_manager = @blog.data_manager.as(Tremolite::DataManager)
      # gather from all posts, flatten and select for only suitable for timeline
      @photo_entities = @posts.map { |p|
        p.published_photo_entities
      }.flatten.select { |p|
        # better to use only gallery capable
        # timeline capable has higher priority
        p.is_gallery
      }.as(Array(PhotoEntity))

      @timeline_photo_entities = @photo_entities.select { |p| p.is_timeline }.as(Array(PhotoEntity))

      @image_url = @blog.data_manager.not_nil!["timeline.backgrounds"].as(String)
      @title = @blog.data_manager.not_nil!["timeline.title"].as(String)
      @subtitle = @blog.data_manager.not_nil!["timeline.subtitle"].as(String)
      @url = "/timeline/photos"

      # we will dive year (366 days) every @quant_days days
      @quant_days = 7
    end

    def inner_html
      return String.build do |s|
        s << load_js_asset("nicechart.master.1.1.js")

        s << "<h3>Zdjęcia czasowe</h3>\n"
        s << "<svg id=\"timeline-chart\"></svg>\n"

        s << "<h3>Zdjęcia we wpisach</h3>\n"
        s << "<svg id=\"published-chart\"></svg>\n"

        s << "<script type=\"text/javascript\">\n"

        # data for chart
        s << "var timelineData = [" + prepare_js_data_from_photo_entities(@timeline_photo_entities) + "];\n"
        s << "var publishedData = [" + prepare_js_data_from_photo_entities(@photo_entities) + "];\n"

        # Bar or Line
        s << "var chartStyle = {chartWidth: 1100, chartHeight: 700, showToolTip: true}\n"
        s << "var axisStyle = {axisXLabelTb: true, axisXLabelSkipIndex: 3}\n"
        s << "var timelineChart = new NiceChart('Line', {renderHere : 'timeline-chart', input: timelineData, axisStyle: axisStyle, chartStyle: chartStyle} ).render();\n"
        s << "var publishedChart = new NiceChart('Line', {renderHere : 'published-chart', input: publishedData, axisStyle: axisStyle, chartStyle: chartStyle} ).render();\n"

        s << "</script>\n"
      end
    end

    def prepare_js_data_from_photo_entities(pes)
      data = prepare_data_from_photo_entities(pes)
      begin_of_year = Time.local(2021, 1, 1)

      return data.map do |time_range, photo_entities|
        x_time = begin_of_year + Time::Span.new(
          days: ((time_range.begin + time_range.end) / 2).to_i,
          hours: 0,
          minutes: 0
        )
        x_label = x_time.to_s("%m-%d")
        y_label = photo_entities.size

        "\"#{x_label},#{y_label}\""
      end.join(", ")
    end

    def prepare_data_from_photo_entities(pes)
      h = Hash(Range(Int32, Int32), Array(PhotoEntity)).new

      d = 0
      while d <= 366
        time_range = Range.new(d, d + @quant_days)

        h[time_range] = pes.select do |pe|
          pe.time.day_of_year >= time_range.begin && pe.time.day_of_year < time_range.end
        end

        d += @quant_days
      end

      return h
    end
  end
end
