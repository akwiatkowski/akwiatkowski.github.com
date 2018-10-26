class TimelineList < PageView

  def initialize(@blog : Tremolite::Blog)
    @posts = @blog.post_collection.posts.select { |p| p.trip? }.as(Array(Tremolite::Post))
    @data_manager = @blog.data_manager.as(Tremolite::DataManager)

    @image_url = @blog.data_manager.not_nil!["timeline.backgrounds"].as(String)
    @title = @blog.data_manager.not_nil!["timeline.title"].as(String)
    @subtitle = @blog.data_manager.not_nil!["timeline.subtitle"].as(String)
    @url = "/timeline"

    
  end

  getter :image_url, :title, :subtitle, :url

  def inner_html
    ""
  end
end
