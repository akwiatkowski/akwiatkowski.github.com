class Tremolite::ImageResizer
  @@sizez = {
    # in post content
    "medium" => {width: 780, height: 520, quality: 88},

    # in index/home page, masonry
    # M43 format for unified homepage images
    "small" => {width: 600, height: 450, quality: 68},
    # "small"     => {width: 600, height: 400, quality: 65},
    # "small_m43" => {width: 600, height: 450, quality: 65},

    # in post list
    "thumb" => {width: 60, height: 40, quality: 50},
    # in map probably
    "big_thumb" => {width: 150, height: 100, quality: 60},
  }
  @@quality = 70
end
