class ExifStatsHelper
  def initialize(
    photos : Array(PhotoEntity) | Nil,
    post : Tremolite::Post | Nil
  )
    @photos = Array(PhotoEntity).new
    @post = post

    @count_by_lens = Hash(String, Int32).new
    @count_by_camera = Hash(String, Int32).new
    @count_by_focal35 = Hash(Int32, Int32).new

    if photos
      append(photos)
    end
  end

  def append(new_photos : Array(PhotoEntity))
    @photos += new_photos
  end

  def make_it_so
    @photos.each do |photo|
      exif = photo.exif

      if exif.camera
        @count_by_camera[exif.camera.to_s] ||= 0
        @count_by_camera[exif.camera.to_s] += 1
      end

      if exif.lens
        if exif.camera
          key = "#{exif.lens} <span class='small'>(#{exif.camera})</span>"
        else
          key = exif.lens.to_s
        end

        @count_by_lens[key] ||= 0
        @count_by_lens[key] += 1
      end

      if exif.focal_length_35
        key = normalize_35mm(exif.focal_length_35.not_nil!).to_i
        @count_by_focal35[key] ||= 0
        @count_by_focal35[key] += 1
      end

      puts exif.focal_length_35
    end
  end

  NORMALIZATION_COEFF = 0.7

  def normalize_35mm(focal_length)
    return (focal_length ** NORMALIZATION_COEFF).round.to_f ** (1.0 / NORMALIZATION_COEFF)
  end

  def generate_table_for_array(
    title_array,
    array
  )
    s = ""
    s += "<table class='table'>\n"
    s += "<thead>\n"

    # header title
    s += "<tr>"
    title_array.each do |title|
      s += "<th>#{title}</th>"
    end
    s += "</tr>"
    s += "</thead>\n"

    # content
    s += "<tbody>\n"
    array.each do |array_row|
      s += "<tr>"
      array_row.each do |cell|
        s += "<td>#{cell}</td>"
      end
      s += "</tr>\n"
    end

    s += "</tbody>\n"
    s += "</table>"

    return s
  end

  def generate_table_for_hash(
    hash,
    title : String
  ) : String
    s = ""

    # descending order
    sorted_keys = hash.keys.sort {|a,b| hash[a] <=> hash[b] }.reverse

    return generate_table_for_array(
      title_array: [title, "Ilość"],
      array: sorted_keys.map {|key| [key, hash[key]] }
    )
  end

  def to_html
    s = ""

    if @count_by_lens.keys.size > 0
      s += generate_table_for_hash(
        hash: @count_by_lens,
        title: "Obiektywy"
      )
    end

    if @count_by_camera.keys.size > 0
      s += generate_table_for_hash(
        hash: @count_by_camera,
        title: "Aparat"
      )
    end

    if @count_by_focal35.keys.size > 0
      array = Array(Array(Int32)).new
      @count_by_focal35.keys.sort.each do |key|
        array << [key, @count_by_focal35[key]]
      end
      s += generate_table_for_array(
        array: array,
        title_array: ["Ogniskowa", "Ilość"]
      )
    end

    return s
  end
end
