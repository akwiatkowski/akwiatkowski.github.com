class Tremolite::ImageResizer
  @@sizez = {
    # Blog posts + gallery lightbox (HiDPI for ~500px display)
    "article" => {width: 1000, height: 800, quality: 85},

    # Homepage/index cards
    "card" => {width: 700, height: 525, quality: 82},

    # Gallery page grid
    "grid" => {width: 560, height: 420, quality: 80},

    # Navigation + map markers
    "thumbnail" => {width: 150, height: 112, quality: 72},
  }
  @@quality = 70

  # AVIF quality ranges per size (min/max for avifenc)
  @@avif_settings = {
    "article"   => {min: 20, max: 40},
    "card"      => {min: 20, max: 40},
    "grid"      => {min: 20, max: 40},
    "thumbnail" => {min: 20, max: 40},
  }
end
