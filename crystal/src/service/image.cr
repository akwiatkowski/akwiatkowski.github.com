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

  # AVIF quality per size (avifenc -q, 0=lossless 100=worst)
  @@avif_settings = {
    "article"   => {quality: 53},
    "card"      => {quality: 53},
    "grid"      => {quality: 53},
    "thumbnail" => {quality: 53},
  }
end
