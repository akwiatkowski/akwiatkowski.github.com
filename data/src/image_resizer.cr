class Tremolite::ImageResizer
  @@sizez = {
    # in post content
    "medium" => {width: 750, height: 600, quality: 88},

    # in index/home page, masonry
    # M43 format for unified homepage images
    "small" => {width: 600, height: 450, quality: 80},

    # in post list
    "thumb" => {width: 60, height: 40, quality: 78},
    # in map probably
    "big_thumb" => {width: 150, height: 100, quality: 80},
    # gallery should have bigger thumbs
    "gallery_thumb" => {width: 320, height: 200, quality: 86},
  }
  @@quality = 70
end
