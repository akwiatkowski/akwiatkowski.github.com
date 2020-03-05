require "./exif_stat_struct"

class ExifStatService
  # better to not add because it makes lens duplicated
  ADD_CAMERA_TO_LENS_NAME = false

  NORMALIZATION_INDEXES = [
    10, 15, 18, # ultra wide
    22, 26, 32, # wide
    40, 60, 80, # normal
    100, 140,   # tele
    180, 250,   # tele 2
    300, 400,   # long tele
    500, 800,   # super tele
    1000        # ulra tele
  ]

  MIN_FOCAL = NORMALIZATION_INDEXES.min
  MAX_FOCAL = NORMALIZATION_INDEXES.max

  NORMALIZATION_RANGES = (1...NORMALIZATION_INDEXES.size).map do |i|
    Range.new(
      NORMALIZATION_INDEXES[i - 1],
      NORMALIZATION_INDEXES[i]
    )
  end

  FOCAL_KEY_PROC = ->(fc : Range(Int32, Int32)) { "#{fc.begin}-#{fc.end}" }

  getter :stats_overall, :stats_by_lens, :stats_by_camera

  def initialize
    @stats_overall = ExifStatStruct.new(
      type: ExifStatType::Overall
    )
    @stats_by_lens = Hash(String, ExifStatStruct).new
    @stats_by_camera = Hash(String, ExifStatStruct).new

    @photos = Array(PhotoEntity).new
  end

  def append(new_photos : Array(PhotoEntity))
    @photos += new_photos
  end

  def make_it_so
    @photos.each do |photo|
      exif = photo.exif

      # there is one overall for all photos
      @stats_overall.increment(photo: photo)

      # one stats per camera
      if exif.camera
        unless @stats_by_camera[exif.camera.to_s]?
          @stats_by_camera[exif.camera.to_s] = ExifStatStruct.new(
            key_name: exif.camera.to_s,
            type: ExifStatType::Camera
          )
        end
        @stats_by_camera[exif.camera.to_s].increment(photo: photo)
      end

      # one stats per lens
      if exif.lens
        unless @stats_by_lens[exif.lens.to_s]?
          @stats_by_lens[exif.lens.to_s] = ExifStatStruct.new(
            key_name: exif.lens.to_s,
            type: ExifStatType::Lens
          )
        end
        @stats_by_lens[exif.lens.to_s].increment(photo: photo)
      end
    end
  end

  def process_focal_hash_to_array_stats(count_by_focal35 : Hash)
    NORMALIZATION_RANGES.map do |fr|
      selected_focals = count_by_focal35.keys.select do |focal|
        fr.begin <= focal && fr.end > focal
      end

      count = selected_focals.map do |focal|
        count_by_focal35[focal]
      end.sum

      {
        from: fr.begin,
        to: fr.end,
        count: count
      }
    end
  end

  def focal_range_stats_overall
    process_focal_hash_to_array_stats(@stats_overall.count_by_focal35)
  end
end
