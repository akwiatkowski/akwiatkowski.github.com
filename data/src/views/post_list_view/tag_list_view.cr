require "./abstract_list_view"

module PostListView
  class TagListView < AbstractListView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @tag : TagEntity)
      @url = @tag.list_url

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

  end
end
