class Tremolite::Post
  MAX_RELATED_POSTS = 8

  def related_posts(blog : Tremolite::Blog)
    # new method
    return related_posts_by_quants(blog: blog)

    # old method
    # return related_posts_by_town(blog: blog)
  end

  # new version using cached coord quants and time diff
  def related_posts_by_quants(blog : Tremolite::Blog)
    service = blog.data_manager.post_coord_quant_cache.not_nil!
    related_data = service.get(self.slug)
    if related_data
      sorted_related = related_data.not_nil![:related_posts].to_a.sort do |a, b|
        a_tuple = a[1]
        b_tuple = b[1]
        # `common_factor` descending
        cf_compare = b_tuple[:common_factor] <=> a_tuple[:common_factor]
        time_compare = b_tuple[:days_diff] <=> a_tuple[:days_diff]

        if cf_compare == 0
          time_compare
        else
          cf_compare
        end
      end
      sorted_slugs = sorted_related.map { |t| t[0].to_s }
      # TODO refactor, make it less ugly
      sorted_posts = sorted_slugs.map do |slug|
        blog.post_collection.posts.select { |post| post.slug == slug }.first.not_nil!
      end
      # filter out not ready posts
      filtered_posts = sorted_posts.select do |post|
        post.ready?
      end
      # truncate result
      return filtered_posts[0...MAX_RELATED_POSTS]
    else
      # when no related posts
      return Array(Tremolite::Post).new
    end
  end

  # old version using towns and time diff
  def related_posts_by_town(blog : Tremolite::Blog)
    posts = blog.post_collection.posts - [self]
    selected_posts = posts.select { |post| self.is_related_to_other_post_by_towns?(post, blog) }
    sorted_posts = selected_posts.sort { |a, b| (self.time - a.time).abs <=> (self.time - b.time).abs }[0...MAX_RELATED_POSTS]
    return sorted_posts
  end

  def is_related_to_other_post_by_towns?(post : Tremolite::Post, blog : Tremolite::Blog) : (Nil | Float64)
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
