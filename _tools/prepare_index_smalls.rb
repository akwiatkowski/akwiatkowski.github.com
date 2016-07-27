require "json"

reset = false # CHANGE
quality = 50 # CHANGE
max = 200 # CHANGE
width = 600.0 # CHANGE

height = width * 2.0 / 3.0
width_int = width.floor
height_int = height.floor
magik_resize = "#{width_int}x#{height_int}"
# http://www.imagemagick.org/Usage/thumbnails/#pad

puts "width_int #{width_int}, #{height_int}"

s = File.read("_site/payload.json")
data = JSON.parse(s)

tmp_path = "_tools/gallery"
resized_path = "img/posts"

Dir.mkdir(tmp_path) unless File.exists?(tmp_path)
Dir.mkdir(resized_path) unless File.exists?(resized_path)

# puts data["posts"][0].keys.inspect

# filtered_data = data["posts"].select{|d| d["header-ext-img"]}.select{|d| d["category"] == "trip"}
filtered_data = data["posts"].select{|d| d["header-ext-img"]}
limited_posts = filtered_data[0...max]

limited_posts.each_with_index do |post, i|
  image_url = post["header-ext-img"]
  url = post["url"]
  title = post["title"]
  date = post["date"]
  slug = post["slug"]

  safe_file_name = "#{date}_#{title.gsub(/\W/,"").gsub(/\s/,"")}"
  padded_i = (i).to_s.rjust(5, '0')
  resized_safe_name = "#{date}_#{slug}"

  puts date

  tmp_file = "#{tmp_path}/#{safe_file_name}.jpg"
  resized_file = "#{resized_path}/#{resized_safe_name}.jpg"
  command = "wget -c \"#{image_url}\" -O#{tmp_file}"
  `#{command}` unless File.exists?(tmp_file)

  command = "convert -resize #{magik_resize} \"#{tmp_file}\" \"#{resized_file}\""
  # puts command
  if File.exists?(resized_file) == false or reset == true
    `#{command}`
  end

end
