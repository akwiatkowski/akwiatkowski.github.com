class Tremolite::Post
  MAX_RELATED_POSTS = 5

  # XXX upgrade in future
  def related_posts(blog : Tremolite::Blog)
    posts = blog.post_collection.posts - [self]
    selected_posts = posts.select { |post| self.is_related_to_other_post?(post, blog) }
    sorted_posts = selected_posts.sort { |a, b| (self.time - a.time).abs <=> (self.time - b.time).abs }[0...MAX_RELATED_POSTS]
    return sorted_posts
  end

  def is_related_to_other_post?(post : Tremolite::Post, blog : Tremolite::Blog) : (Nil | Float64)
    towns = blog.data_manager.not_nil!.town_slugs.not_nil!
    if self.towns && post.towns
      self_towns = self.towns.not_nil!.select { |t| towns.includes?(t) }
      other_towns = post.towns.not_nil!.select { |t| towns.includes?(t) }

      common_size = (self_towns & other_towns).size

      return nil if 0 == common_size
      # maybe some distance calculation in future
      # one town is not enough to be related when route has more towns
      return nil if (1 == common_size) && (self_towns.size > 1) && (other_towns.size > 1)
      return 1.0
    end
    return nil
  end
end
