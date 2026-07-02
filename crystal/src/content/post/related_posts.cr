class Tremolite::Post
  MAX_RELATED_POSTS = 8

  def related_posts(context : RenderContext)
    # new method
    return related_posts_by_quants(context: context)
  end

  # new version using cached coord quants and time diff
  def related_posts_by_quants(context : RenderContext)
    service = context.post_coord_quant_cache
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
      # Resolve slugs to loaded posts, skipping any that no longer resolve.
      # Coord-quant caches can reference slugs that are stale (renamed posts) or
      # not in the current collection (e.g. drafts excluded from this build), so
      # a missing slug must be skipped, not crash the whole render.
      posts_by_slug = context.posts.index_by(&.slug)
      sorted_posts = sorted_slugs.compact_map { |slug| posts_by_slug[slug]? }
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
end
