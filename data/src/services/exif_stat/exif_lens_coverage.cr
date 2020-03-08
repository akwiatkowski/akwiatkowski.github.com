class ExifStat::ExifLensCoverage
  LENSES = {
    # m43 lens
    "LUMIX 14-140/F3.5-5.6" => {
      exif: "LUMIX G VARIO 14-140/F3.5-5.6",
      ranges: [
        {
          from: 14*2,
          to: 140*2,
        }
      ],
      weight: 265,
      quality: 2, # subjective image quality
      mount: :m43,
    },
    "LEICA 8-18/F2.8-4" => {
      exif: "LEICA 8-18/F2.8-4", # TODO
      ranges: [
        {
          from: 8*2,
          to: 18*2,
        }
      ],
      weight: 315,
      quality: 5, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 12-100mm/F4.0" => {
      exif: "OLYMPUS M.12-100mm F4.0",
      ranges: [
        {
          from: 12*2,
          to: 100*2,
        }
      ],
      weight: 561,
      quality: 5, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 12-40mm/F2.8" => {
      exif: "OLYMPUS M.12-40mm F2.8", # TODO
      ranges: [
        {
          from: 12*2,
          to: 40*2,
        }
      ],
      weight: 382,
      quality: 5, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 40-150mm/F2.8 TC" => {
      exif: [
        "M.40-150mm F2.8 + MC-14",
        "M.40-150mm F2.8"
      ],
      ranges: [
        {
          from: 40*2,
          to: (150.0*1.4*2.0).to_i, # with teleconverter,
        }
      ],
      weight: 900,
      quality: 5, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 75-300mm/F4.8-6.7" => {
      exif: "OLYMPUS M.75-300mm F4.8-6.7 II",
      ranges: [
        {
          from: 75*2,
          to: 300*2,
        }
      ],
      weight: 423,
      quality: 3, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 60mm/2.8" => {
      exif: "OLYMPUS M.60mm F2.8 Macro",
      ranges: [
        {
          from: 60*2,
          to: 70*2,
        }
      ],
      weight: 186,
      quality: 6, # subjective image quality
      mount: :m43,
    },
    "OLYMPUS 75mm/1.8" => {
      exif: "", # TODO
      ranges: [
        {
          from: 75*2,
          to: 85*2,
        }
      ],
      weight: 305,
      quality: 7, # subjective image quality
      mount: :m43,
    },
    # sony FE
    "TAMRON 28-75mm/F2.8" => {
      exif: "E 28-75mm F2.8-2.8",
      ranges: [
        {
          from: 28,
          to: 75,
        }
      ],
      weight: 550,
      quality: 8, # subjective image quality
      mount: :sony_fe,
    },
    "TAMRON 17-28mm/F2.8" => {
      exif: "E 17-28mm F2.8-2.8", # TODO
      ranges: [
        {
          from: 17,
          to: 28,
        }
      ],
      weight: 420,
      quality: 8, # subjective image quality
      mount: :sony_fe,
    },
    "TAMRON 70-180mm/F2.8" => {
      exif: "E 70-180mm F2.8-2.8",
      ranges: [
        {
          from: 70,
          to: 180,
        }
      ],
      weight: 815,
      quality: 8, # subjective image quality
      mount: :sony_fe,
    },
    "TOKINA 20mm/F2" => {
      exif: "E 20mm F2",
      ranges: [
        {
          from: 20,
          to: 24, # we can crop from prime
        }
      ],
      weight: 490,
      quality: 10, # subjective image quality
      mount: :sony_fe,
    },
    "SONY 85mm/F1.8" => {
      exif: "FE 85mm F1.8",
      ranges: [
        {
          from: 85,
          to: 100, # we can crop from prime
        }
      ],
      weight: 371,
      quality: 10, # subjective image quality
      mount: :sony_fe,
    }
  }

  # list of combination lenses
  # because I think it's better than permutations
  #
  # old one, not used but no removing this
  LENS_SETS_DEFINITIONS = [
    [
      "OLYMPUS 12-100mm/F4.0",
      "OLYMPUS 40-150mm/F2.8 TC"
    ],
    [
      "OLYMPUS 12-40mm/F2.8",
      "OLYMPUS 40-150mm/F2.8 TC"
    ],
    [
      "LEICA 8-18/F2.8-4",
      "OLYMPUS 40-150mm/F2.8 TC"
    ],
    [
      "LEICA 8-18/F2.8-4",
      "OLYMPUS 12-100mm/F4.0"
    ],
    [
      "LEICA 8-18/F2.8-4",
      "OLYMPUS 12-40mm/F2.8",
      "OLYMPUS 40-150mm/F2.8 TC"
    ],
    # 3 tamron sets
    [
      "TAMRON 17-28mm/F2.8",
      "TAMRON 28-75mm/F2.8",
      "TAMRON 70-180mm/F2.8"
    ],
    [
      "TAMRON 28-75mm/F2.8",
      "TAMRON 70-180mm/F2.8"
    ],
    [
      "TAMRON 17-28mm/F2.8",
      "TAMRON 28-75mm/F2.8",
    ],
    [
      "TAMRON 17-28mm/F2.8",
      "TAMRON 70-180mm/F2.8"
    ]
  ]
  LENS_SETS_AND_SINGLE = LENSES.keys.map {|l| [l] } + LENS_SETS_DEFINITIONS
  LENSES_LIST = LENS_SETS_AND_SINGLE.map do |lens_defs|
    # array
    lenses = lens_defs.map do |lens_name|
      LENSES[lens_name]
    end

    name = lens_defs.join(" + ")
    ranges = lenses.map {|l| l[:ranges] }.flatten
    weight = lenses.map {|l| l[:weight].as(Int32) }.sum
    mounts = lenses.map {|l| l[:mount] }.flatten
    camera_weight = mounts.map {|m| CAMERAS[m][:weight].as(Int32) }.sum

    {
      name: name,
      ranges: ranges,
      weight: weight,
      camera_weight: camera_weight,
      # quality: 8 # TODO not important right now
    }
  end

  # new attempt to calculate useful stats
  LENSES_ARRAY = LENSES.keys.map do |lens_name|
    camera_weight = CAMERAS[LENSES[lens_name][:mount]][:weight].as(Int32)
    LENSES[lens_name].merge(
      {
        name: lens_name,
        camera_weight: camera_weight,
      }
    )
  end

  CAMERAS = {
    :m43 => {
      weight: 574,
    },
    :sony_fe => {
      weight: 465,
    }
  }


  def initialize(
    @stats_struct : ExifStatStruct
  )
  end

  # render table which will calculate how lens would be useful to me
  # old one
  def data_for_lens_focal_coverage
    total_count = @stats_struct.count
    array_ah_calculated = LENSES_LIST.map do |lens_hash|
      lens_count = @stats_struct.count_between_focal35(
        lens_hash[:ranges],
      )

      total_weight = lens_hash[:weight] + lens_hash[:camera_weight]
      percentage = 100.0 * lens_count.to_f / total_count.to_f
      perc_per_weight = 1000.0 * percentage / total_weight.to_f

      {
        name: lens_hash[:name],
        count: lens_count,
        percentage: percentage.to_i,
        lens_weight: lens_hash[:weight],
        camera_weight: lens_hash[:camera_weight],
        total_weight: total_weight,
        perc_per_weight: perc_per_weight.to_i,
      }
    end

    array_ah = array_ah_calculated.select do |lh|
      # we want only useful lenses
      lh[:percentage] > 5
    end.sort do |a,b|
      b[:percentage] <=> a[:percentage]
    end

    return array_ah
  end

  # render data to analyze what lenses are most useful
  # new one
  PHOTP_KIT_INITIAL_PERCENT = 40
  PHOTO_KIT_OTHER_ADD_LENS_PERCENT = 5

  def photo_kit_coverage_data
    total_count = @stats_struct.count
    # calculate lens usefulness stats
    ls_calculated = LENSES_ARRAY.map do |lens_hash|
      lens_count = @stats_struct.count_between_focal35(
        lens_hash[:ranges],
      )

      total_weight = lens_hash[:weight] + lens_hash[:camera_weight]
      percentage = 100.0 * lens_count.to_f / total_count.to_f
      perc_per_weight = 1000.0 * percentage / total_weight.to_f

      {
        name: lens_hash[:name],
        mount: lens_hash[:mount],
        ranges: lens_hash[:ranges],
        count: lens_count,
        percentage: percentage.to_i,
        weight: lens_hash[:weight],
        camera_weight: lens_hash[:camera_weight],
        total_weight: total_weight,
        perc_per_weight: perc_per_weight.to_i,
      }
    end

    # filter and sorot for only best useful
    ls_selected = ls_calculated.select do |lh|
      # we want only most useful lens
      lh[:percentage] > PHOTP_KIT_INITIAL_PERCENT
    end.sort do |a,b|
      b[:percentage] <=> a[:percentage]
    end

    # add other possible lenses
    kit_data = ls_selected.map do |lens_hash|
      # select other lenses for same mount
      other_lenses = ls_calculated.select do |other_lens|
        other_lens[:name] != lens_hash[:name] && lens_hash[:mount] == other_lens[:mount]
      end

      # calculate how much adding that lens add to kit
      other_lenses_data = other_lenses.map do |other_lens|
        additional_lens_count = @stats_struct.count_between_focal35(
          other_lens[:ranges],
          except: lens_hash[:ranges]
        )
        # we have number of photos which could be taken
        # if we have added that lens into our kit

        additional_percentage = 100.0 * additional_lens_count.to_f / total_count.to_f
        perc_per_weight = 1000.0 * additional_percentage / other_lens[:weight].to_f

        total_percentage = lens_hash[:percentage] + additional_percentage.to_i
        total_weight = other_lens[:weight] + lens_hash[:weight]
        total_perc_per_weight = 1000.0 * total_percentage / total_weight.to_f

        {
          name: other_lens[:name],
          mount: other_lens[:mount],
          ranges: other_lens[:ranges],
          additional_count: additional_lens_count,
          additional_percentage: additional_percentage.to_i,
          percentage: total_percentage,
          count: lens_hash[:count] + additional_lens_count.to_i,
          weight: other_lens[:weight],
          total_weight: total_weight,
          perc_per_weight: perc_per_weight.to_i,
          total_perc_per_weight: total_perc_per_weight.to_i,
        }
      end

      # select only useful other lenses
      # if lens add leass then `PHOTO_KIT_OTHER_ADD_LENS_PERCENT` percent
      # it's not useful in our case
      other_useful_lenses = other_lenses_data.select do |other_lens|
        other_lens[:additional_percentage] >= PHOTO_KIT_OTHER_ADD_LENS_PERCENT
      end.sort do |a,b|
        # and order from most useful
        b[:additional_percentage] <=> a[:additional_percentage]
      end

      {
        lens: lens_hash,
        other_useful_lenses: other_useful_lenses
      }
    end

    return kit_data
  end

end
