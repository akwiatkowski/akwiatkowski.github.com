class Tremolite::ImageResizer
  @@sizez = {
    "medium" => {width: 780, height: 520, quality: 88},
    "small" => {width: 600, height: 400, quality: 65},
    "thumb" => {width: 60, height: 40, quality: 50},
    "big_thumb" => {width: 150, height: 100, quality: 60},
  }
  @@quality = 70
end
