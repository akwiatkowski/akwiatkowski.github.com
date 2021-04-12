require "./abstract_masonry_view"

module PostListView
  class VoivodeshipMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @voivodeship : VoivodeshipEntity,
      @only_ready = true
    )
      @show_only_count = 8
      @url = @voivodeship.masonry_url

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @voivodeship.belongs_to_post?(post)
          @posts << post
        end
      end
    end

    def title
      @voivodeship.name
    end

    def image_url
      return @voivodeship.image_url
    end
  end
end
