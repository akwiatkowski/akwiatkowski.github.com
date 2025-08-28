require "./abstract_masonry_view"

module PostListView
  class TagMasonryView < AbstractMasonryView
    Log = ::Log.for(self)

    def initialize(
      @blog : Tremolite::Blog,
      @tag : TagEntity,
      @only_ready = true,
    )
      @url = @tag.masonry_url
      @show_only_count = 8

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @tag.belongs_to_post?(post)
          @posts << post
        end
      end
    end

    def title
      @tag.name
    end

    def image_url
      return @tag.image_url
    end

    # already added to array in constructor
    def post_list
      @posts
    end
  end
end
