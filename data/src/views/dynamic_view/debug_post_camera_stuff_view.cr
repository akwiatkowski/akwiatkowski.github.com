require "../wider_page_view"

module DynamicView
  class DebugPostCameraStuffView < WiderPageView
    Log = ::Log.for(self)

    def initialize(@blog : Tremolite::Blog)
      # only posts with filters
      @posts = @blog.post_collection.posts.as(Array(Tremolite::Post)).select do |post|
        post.published_photo_entities.size > 0
      end.as(Array(Tremolite::Post))
      @image_url = generate_image_url.as(String)
      @title = "Jaki sprzęt wziąłem?"
      @subtitle = "liczone będą tylko zdjęcia upublicznione we wpisach"
      @url = "/debug/posts_camera_stuff"
    end

    getter :image_url, :title, :subtitle
    property :url

    WEIGHTS = {
      "Pentax FA 50mm Macro"            => 265,
      "Sigma 18-200mm (old)"            => 405,
      "Pentax DA 16-45mm f4"            => 356,
      "Pentax DA 35mm f2.4"             => 124,
      "Pentax Limited 15mm f4"          => 190,
      "Pentax Limited 70mm f2.4"        => 130,
      "Pentax Limited 40mm f2.8"        => 89,
      "Sigma 150-500mm"                 => 1910,
      "Lumix 20mm f1.7"                 => 100,
      "Olympus M10m2"                   => 400,
      "Pentax K-S2"                     => 678,
      "Pentax K-5"                      => 740,
      "Pentax K100D"                    => 660,
      "Olympus 60mm Macro"              => 185,
      "Olympus 14-42mm Kit"             => 190,
      "Olympus 9-18mm"                  => 155,
      "Olympus 12-100mm f4"             => 561,
      "Olympus 75-300mm"                => 423,
      "Olympus 17mm f1.2"               => 390,
      "Olympus 25mm f1.2"               => 410,
      "Olympus 40-150mm f2.8"           => 760,
      "Lumix 14-140mm"                  => 265,
      "Sony 85mm f1.8"                  => 371,
      "Tokina 20mm f2"                  => 490,
      "Olympus 40-150mm f2.8 + TC 1.4x" => 760 + 170,
      "Tamron 28-75mm f2.8"             => 550,
      "Sigma 100-400mm f5-6.3"          => 1160,
      "Sigma 105mm f1.4"                => 1645,
      "Olympus 300mm f4"                => 1475,
      "Olympus 75mm f1.8"               => 305,
      "Olympus M1m3"                    => 580,
      "Olympus M1m2"                    => 574,
    }

    def inner_html
      result = String.build do |s|
        s << "<table class=\"table small\">\n"

        s << "<tr>\n"
        s << "<th></th>\n"
        TABLE_HEADERS.values.each do |header_title|
          s << "<th>#{header_title}</th>\n"
        end
        s << "</tr>\n"

        post_array = @posts.map { |post| post_tuple(post) }
        post_array.each_with_index do |tuple, i|
          s << "<tr>\n"
          s << "<td>#{i + 1}</td>\n"
          TABLE_HEADERS.keys.each do |key|
            value = tuple[key]

            # bootstrap icons https://icons.getbootstrap.com
            if value.to_s == true.to_s
              inner_symbol = "&check;"
              value_string = "<button type=\"button\" class=\"btn btn-sm\">#{inner_symbol}</button>\n"
            elsif value.to_s == false.to_s
              value_string = ""
              # blank instead of "&cross;"
            else
              value_string = value.to_s
            end

            if key == :title || key == :title_short
              url = tuple[:post].url
              value_string = "<a href=\"#{url}\">#{value_string}</a>"
            end

            s << "<td>#{value_string}</td>\n"
          end
          s << "</tr>\n"
        end
        s << "</table>\n"
      end

      return short_name(result)
    end

    TABLE_HEADERS = {
      title_short:              "Tytuł",
      photo_count_string: "Ilosć zdj.",
      main_camera:        "Gł. aparat",
      main_lens:          "Gł. obiektyw",
      main_weight:        "Gł. waga",
      lenses_string:      "Obiektywy",
      # total_weight:       "Waga całk.",
    }

    def post_tuple(post)
      published_photos = post.published_photo_entities
      lenses, cameras = camera_and_lens_for_entities(published_photos)

      main_lens = nil
      main_lens_count = 0
      main_lens_weight = nil
      lenses_string = ""
      if lenses.size > 0
        main_lens = lenses.last[0]
        main_lens_count = lenses.last[1]
        main_lens_weight = WEIGHTS[main_lens]?

        lenses.each do |l|
          if l != main_lens
            # loop for other lenses
            l_name = l[0]
            l_count = l[1]
            l_weight = WEIGHTS[l_name]?
            l_weight_string = l_weight ? " (#{l_weight}g)" : ""
            lenses_string += "#{l_count}x #{l_name}#{l_weight_string}<br>"
          end
        end

        lenses_string
      end

      main_camera = nil
      main_camera_count = 0
      main_camera_weight = nil
      if cameras.size > 0
        main_camera = cameras.last[0]
        main_camera_count = cameras.last[1]
        main_camera_weight = WEIGHTS[main_camera]?
      end

      main_weight = nil
      if main_lens_weight && main_camera_weight
        main_weight = main_lens_weight + main_camera_weight
      end

      return {
        post:               post,
        title:              post.title,
        title_short:              post.title[0..20],
        photo_count:        published_photos.size,
        photo_count_string: "#{main_lens_count} / #{published_photos.size}",
        main_camera:        main_camera,
        main_lens:          main_lens,
        main_weight:        main_weight,
        lenses_string:      lenses_string,
        total_weight:       nil,
      }
    end

    def camera_and_lens_for_entities(photos)
      lenses = Hash(String, Int32).new
      cameras = Hash(String, Int32).new

      photos.each do |pe|
        lens_name = pe.exif.not_nil!.lens_name
        camera_name = pe.exif.not_nil!.camera_name

        if lens_name
          lenses[lens_name.not_nil!] ||= 0
          lenses[lens_name.not_nil!] += 1
        end

        if camera_name
          cameras[camera_name.not_nil!] ||= 0
          cameras[camera_name.not_nil!] += 1
        end
      end

      return lenses.to_a.sort { |a, b| a[1] <=> b[1] }, cameras.to_a.sort { |a, b| a[1] <=> b[1] }
    end

    def short_name(name)
      name.gsub("Sigma 100-400mm f5-6.3", "Sigma 100-400mm").
        gsub(" + TC 1.4x", "+1.4x").
        gsub(" + TC 2.0x", "+2.0x").
        gsub("Olympus", "Ol").
        gsub("Pentax Limited", "Ptx L").
        gsub("Pentax", "Ptx").
        gsub("Macro", "m.").
        gsub("Sigma", "Sig").
        gsub("Sony", "Sny").
        gsub("Tamron", "Tamr").
        gsub("Tokina", "Tkina")
    end

    private def generate_image_url
      return @posts.last.image_url
    end
  end
end
