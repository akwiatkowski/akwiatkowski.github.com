module DynamicView
  class PortfolioView < BaseView
    Log = ::Log.for(self)

    getter :title

    def initialize(context : RenderContext, @url = "/portfolio")
      super(context: context, url: @url)
      @title = context["portfolio.title"]
    end

    def add_to_sitemap?
      false
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
      photo_entities = context.exif_db.all_flatten_photo_entities.select do |photo_entity|
        photo_entity.tags.includes?("portfolio")
      end
      portfolios = context.portfolios

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
    end
  end
end
