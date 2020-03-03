class ExifStatsHelper
  NORMALIZATION_INDEXES = [
    15, 18, # ultra wide
    22, 26, 32, # wide
    40, 60, 80, # normal
    100, 140, # tele
    180, 250, # tele 2
    300, 400, # long tele
    500, # super tele
  ]

  MIN_FOCAL = NORMALIZATION_INDEXES.min
  MAX_FOCAL = NORMALIZATION_INDEXES.max

  NORMALIZATION_RANGES = (1...NORMALIZATION_INDEXES.size).map do |i|
    Range.new(
      NORMALIZATION_INDEXES[i - 1],
      NORMALIZATION_INDEXES[i]
    )
  end

  FOCAL_KEY_PROC = ->(fc : Range(Int32, Int32)) { "#{fc.begin}-#{fc.end} mm" }

  MIN_FOCAL_KEY = "< #{MIN_FOCAL} mm"
  MAX_FOCAL_KEY = "> #{MAX_FOCAL} mm"

  def initialize(
    photos : Array(PhotoEntity) | Nil,
    post : Tremolite::Post | Nil
  )
    @photos = Array(PhotoEntity).new
    @post = post

    @count_by_lens = Hash(String, Int32).new
    @count_by_camera = Hash(String, Int32).new

    @count_by_focal35 = Hash(Int32, Int32).new
    @count_by_focal35_lower = 0
    @count_by_focal35_higher = 0

    if photos
      append(photos)
    end
  end

  def append(new_photos : Array(PhotoEntity))
    @photos += new_photos
  end

  def make_it_so
    focal_ranges = NORMALIZATION_INDEXES

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
        focal_int = exif.focal_length_35.not_nil!.round
        if focal_int < MIN_FOCAL
          @count_by_focal35_lower += 1
        elsif focal_int > MAX_FOCAL
          @count_by_focal35_higher += 1
        else
          focal_range = NORMALIZATION_RANGES.select{ |fr| fr.covers?(focal_int) }.first
          @count_by_focal35[focal_range.begin] ||= 0
          @count_by_focal35[focal_range.begin] += 1
        end
      end
    end
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
    s += "</tr>\n"
    s += "</thead>\n"

    # content
    s += "<tbody>\n"
    array.each do |array_row|
      s += "<tr>"
      array_row.each do |cell|
        if cell
          s += "<td>#{cell}</td>"
        else
          s += "<td\>"
        end
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
      titles = Array(String).new
      values = Array(Int32 | Nil).new

      if @count_by_focal35_lower > 0
        titles << "&lt; #{MIN_FOCAL}mm"
        values << @count_by_focal35_lower
      end

      @count_by_focal35.keys.sort.each do |focal_range_begin|
        focal_range = NORMALIZATION_RANGES.select{|fr| fr.begin == focal_range_begin}.first
        title = FOCAL_KEY_PROC.call(focal_range)
        value = @count_by_focal35[focal_range_begin]

        titles << title
        values << value
      end

      if @count_by_focal35_higher > 0
        titles << "&gt; #{MAX_FOCAL}mm"
        values << @count_by_focal35_higher
      end

      if titles.size > 0
        focal_ranges_html = generate_table_for_array(
          array: [ [nil] + values],
          title_array: ["Ogniskowa"] + titles
        )

        s += focal_ranges_html
      end
    end

    return s
  end
end
