module DynamicView
  class PortfolioView < BaseView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog, @url = "/portfolio")
    end

    def title
      @blog.data_manager.not_nil!["portfolio.title"]
    end

    def meta_keywords_string
      return "portfolio"
    end

    def meta_description_string
      page_desc
    end

    def page_desc
      return "Aleksander Kwiatkowski portfolio fotograficzne"
    end

    def content
      photo_entities = @blog.data_manager.exif_db.all_flatten_photo_entities.select do |photo_entity|
        photo_entity.tags.includes?("portfolio")
      end
      portfolios = @blog.data_manager.portfolios.not_nil!

      content_string = String.build do |s|
        photo_entities.each_with_index do |photo_entity, i|
          # find long_desc from portfolio.yml
          selected_portfolio = portfolios.select do |portfolio|
            portfolio.post_slug == photo_entity.post_slug && portfolio.image_filename == photo_entity.image_filename
          end

          ph = Hash(String, String).new
          ph["img.src"] = photo_entity.full_image_src
          ph["img.title"] = photo_entity.desc
          ph["post.url"] = photo_entity.post_url

          # debug info
          ph["post.slug"] = photo_entity.post_slug
          ph["img.filename"] = photo_entity.image_filename

          # use long_desc from yaml file
          if selected_portfolio.size > 0
            ph["img.desc"] = selected_portfolio[0].long_desc
          else
            ph["img.desc"] = ""
          end

          ph["carousel-active"] = ""
          ph["carousel-active"] = "active" if i == 0
          ph["index"] = i.to_s

          s << load_html("portfolio/section", ph)
        end
      end

      indicators_string = String.build do |s|
        photo_entities.each_with_index do |photo_entity, i|
          ph = Hash(String, String).new
          ph["carousel-active"] = ""
          ph["carousel-active"] = "active" if i == 0
          ph["index"] = i.to_s

          s << load_html("portfolio/indicator", ph)
        end
      end

      ph = Hash(String, String).new
      ph["content"] = content_string
      ph["indicators"] = indicators_string
      return load_html("portfolio/page", ph)

      data = Hash(String, String).new

      boxes = ""
      count = 0

      # only non-todo, and main tagged posts
      posts = @blog.post_collection.posts.select { |p| (p.tags.not_nil!.includes?("todo") == false) && (p.tags.not_nil!.includes?("main") == true) }
      # sorted by date descending
      posts = posts.sort { |a, b| b.time <=> a.time }

      posts.each do |post|
        boxes += "\n"

        count += 1
      end

      data["postbox"] = boxes
      return load_html("home", data)
    end
  end
end
