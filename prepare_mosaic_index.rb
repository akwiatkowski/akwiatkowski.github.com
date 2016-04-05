require "json"

x = 6
y = 6
max = x*y

width = 2048.0 / 3.0
height = width * 2.0 / 3.0
width_int = width.floor
height_int = height.floor
magik_resize = "#{width_int}x#{height_int}^"
# http://www.imagemagick.org/Usage/thumbnails/#pad

quality = 30

output = "img/mosaic.jpg"
output_html = "_includes/mosaic.html"

s = File.read("_site/payload.json")
data = JSON.parse(s)

tmp_path = "_tmp/index"
resized_path = "_tmp/index/resized"

Dir.mkdir(tmp_path) unless File.exists?(tmp_path)
Dir.mkdir(resized_path) unless File.exists?(resized_path)

`rm #{File.join(resized_path, "*")}`
`rm #{output}`

puts data["posts"][0].keys.inspect
filtered_data = data["posts"].select{|d| d["header-ext-img"]}.select{|d| d["category"] == "trip"}
limited_posts = filtered_data[0...max]

limited_posts.each_with_index do |post, i|
  image_url = post["header-ext-img"]
  url = post["url"]
  title = post["title"]
  date = post["date"]

  safe_file_name = "#{date}_#{title.gsub(/\W/,"").gsub(/\s/,"")}"
  padded_i = (i).to_s.rjust(5, '0')
  resized_safe_name = "#{padded_i}_#{safe_file_name}"

  puts date

  tmp_file = "_tmp/index/#{safe_file_name}.jpg"
  resized_file = "_tmp/index/resized/#{resized_safe_name}.jpg"
  command = "wget -c \"#{image_url}\" -O#{tmp_file}"
  `#{command}` unless File.exists?(tmp_file)

  command = "convert -resize #{magik_resize} \"#{tmp_file}\" \"#{resized_file}\""
  `#{command}`

end

command = "montage -quality #{quality} -mode concatenate -tile #{x}x#{y} \"#{File.join(resized_path, "*")}\" #{output}"
`#{command}`

# map

s = ""
s += "<img src=\"/#{output}\" width=\"#{width_int * x}\" height=\"#{height_int * y}\" alt=\"Wpisy\" usemap=\"#postmap\">\n"
s += "<map name=\"postmap\">\n"

xi = 0
yi = 0
limited_posts.each_with_index do |post, i|
  url = post["url"]
  title = post["title"]
  s += "<area shape=\"rect\" coords=\"#{xi * width_int},#{yi * height_int},#{(xi+1) * width_int},#{(yi+1) * height_int}\" href=\"#{url}\" alt=\"#{title}\">\n"

  # move to next
  xi += 1
  if xi >= x
    xi = 0
    yi += 1
  end
end

s += "</map>\n"

f = File.new(output_html, "w")
f.puts(s)
f.close
