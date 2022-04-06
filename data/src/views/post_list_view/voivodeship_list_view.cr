require "./abstract_list_view"

module PostListView
  class VoivodeshipListView < AbstractListView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @voivodeship : VoivodeshipEntity)
      @url = @voivodeship.list_url

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
      if @posts.size > 0
        return @posts.select { |p| p.ready? }.first.image_url
      end

      return @voivodeship.image_url
    end
  end
end
