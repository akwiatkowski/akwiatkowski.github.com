class Tremolite::Validator
  def custom_validators
    check_missing_towns
  end

  private def check_missing_towns
    all_towns_or_voivodeships = (@blog.data_manager.not_nil!.towns.not_nil! + @blog.data_manager.not_nil!.voivodeships.not_nil!).map(&.slug)
    posts = @blog.post_collection.posts.sort { |a, b| b.time <=> a.time }

    self_propelled_posts = posts.select{ |post| post.self_propelled? }
    not_self_propelled_posts = posts.select{ |post| post.self_propelled? != true }

    # self propelled posts should have defined towns
    self_propelled_posts.each do |post|
      towns_or_voivodeships = post.towns.not_nil!
      self_propelled = post.self_propelled?

      towns_or_voivodeships.each do |slug|
        common_count = all_towns_or_voivodeships.select { |s| slug == s }.size
        if common_count == 0
            error_in_post(post, "missing town #{slug}")
        end
      end
    end

    # not self propelled posts towns are optional
    not_self_propelled_posts.each do |post|
      towns_or_voivodeships = post.towns.not_nil!
      self_propelled = post.self_propelled?

      towns_or_voivodeships.each do |slug|
        common_count = all_towns_or_voivodeships.select { |s| slug == s }.size
        if common_count == 0
            warning_in_post(post, "missing town #{slug}")
        end
      end
    end
  end
end
