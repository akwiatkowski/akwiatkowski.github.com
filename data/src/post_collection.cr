class Tremolite::PostCollection
  def each_post_file(&block : String -> Nil)
    Dir[File.join([@posts_path, "**", "*.#{@posts_ext}"])].sort.each do |post_path|
      block.call(post_path)
    end
  end

  def ensure_posts_have_assigned_lands
    posts.each do |post|
      puts post.slug
      puts post.lands
      puts "-"
    end
  end
end
