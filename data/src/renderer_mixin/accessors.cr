module RendererMixin::Accessors
  def validator
    return @blog.validator.not_nil!
  end

  def posts_descending
    return @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }
  end

  def blog
    return @blog
  end
end
