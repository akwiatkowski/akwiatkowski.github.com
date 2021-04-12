require "./abstract_masonry_view"

module PostListView
  class LandMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @land : LandEntity,
      @only_ready = true
    )
      @show_only_count = 8
      @url = @land.masonry_url

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @land.belongs_to_post?(post)
          @posts << post
        end
      end
      puts "#{@land.name} - #{@posts.size}"
    end

    def title
      @land.name
    end

    def image_url
      return @land.image_url
    end
  end
end
