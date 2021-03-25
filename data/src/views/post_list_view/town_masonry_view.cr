require "./abstract_masonry_view"

module PostListView
  class TownMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @town : TownEntity,
      @only_ready = true
    )
      @show_only_count = 8
      @url = @town.masonry_url

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @town.belongs_to_post?(post)
          @posts << post
        end
      end
    end

    def title
      @town.name
    end

    def image_url
      return @town.image_url
    end

  end
end
