require "./abstract_list_view"

module PostListView
  class LandListView < AbstractListView
    Log = ::Log.for(self)

    @preselected_size : Int32?

    def initialize(@blog : Tremolite::Blog, @land : LandEntity)
      @url = @land.list_url

      @posts = Array(Tremolite::Post).new
      @blog.post_collection.each_post_from_latest do |post|
        if @land.belongs_to_post?(post)
          @posts << post
        end
      end
    end

    def title
      @land.name
    end

    def image_url
      return @land.image_url
    end
  end
end
