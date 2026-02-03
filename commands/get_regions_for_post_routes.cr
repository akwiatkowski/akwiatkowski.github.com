require "../data/src/tremolite/tremolite"
require "../data/src/blog"
require "../data/src/services/area_matcher/all"

# Example route points [lat, lon]
route_points = [
  [52.492009, 17.206358], [52.492302, 17.206496], [52.49331, 17.206753],
  [52.493369, 17.206258], [52.493497, 17.204283], [52.494017, 17.200114],
  [52.494302, 17.200212], [52.498234, 17.20217], [52.498475, 17.202425],
  [52.498734, 17.202556], [52.499089, 17.202676], [52.504771, 17.205504],
  [52.50495, 17.205864], [52.505203, 17.206147], [52.506621, 17.208077],
  [52.506495, 17.208477], [52.506467, 17.208961], [52.506458, 17.213539],
  [52.506731, 17.213615], [52.507059, 17.213775], [52.507319, 17.214011],
  [52.507796, 17.214555], [52.5077, 17.215037], [52.507804, 17.21554],
  [52.507993, 17.215963], [52.514831, 17.231495], [52.521669, 17.247006],
  [52.522658, 17.249879], [52.522441, 17.250207], [52.522122, 17.250788],
  [52.521052, 17.253226], [52.521216, 17.253608], [52.521437, 17.253925],
  [52.521996, 17.254595], [52.530839, 17.267142], [52.534137, 17.271028],
  [52.534272, 17.270635], [52.534326, 17.270154], [52.537268, 17.252834],
  [52.537508, 17.252481], [52.538403, 17.251404], [52.53884, 17.25075],
  [52.539032, 17.250335], [52.539323, 17.250075], [52.54064, 17.249161],
  [52.540921, 17.249054], [52.548763, 17.24483], [52.548997, 17.244544],
  [52.552213, 17.241324], [52.552525, 17.241288], [52.55417, 17.240794],
  [52.554185, 17.240301], [52.554251, 17.23961], [52.554465, 17.239225],
  [52.554713, 17.239], [52.555102, 17.238736], [52.555639, 17.238257],
  [52.555804, 17.237903], [52.555946, 17.237473], [52.556053, 17.237015],
  [52.556166, 17.236354], [52.556217, 17.235902], [52.556396, 17.234914],
  [52.556554, 17.234477], [52.557291, 17.232836], [52.557531, 17.232526],
  [52.557818, 17.232293], [52.558149, 17.232323], [52.567233, 17.234468],
  [52.567498, 17.234591], [52.578293, 17.237916], [52.578554, 17.23766],
  [52.579302, 17.237069], [52.579597, 17.236925], [52.58333, 17.234476],
  [52.583558, 17.234126], [52.584516, 17.232358], [52.584412, 17.231911],
  [52.584265, 17.231518], [52.581855, 17.223582], [52.581842, 17.223081],
  [52.58069, 17.208628], [52.580594, 17.208166], [52.576169, 17.191808],
]

puts "Loading area matcher..."
matcher = AreaMatcher::Matcher.new
puts "Stats: #{matcher.stats}"

puts "\n--- Testing single point ---"
result = matcher.match_point(52.492009, 17.206358)
puts "Towns: #{result.towns.map(&.name)}"
puts "Counties: #{result.counties.map(&.name)}"
puts "Voivodeships: #{result.voivodeships.map(&.name)}"
puts "Meso regions: #{result.meso_regions.map(&.name)}"

puts "\n--- Testing route points (#{route_points.size} points) ---"
result = matcher.match_points(route_points)
puts "Towns: #{result.towns.map(&.name)}"
puts "Counties: #{result.counties.map(&.name)}"
puts "Voivodeships: #{result.voivodeships.map(&.name)}"
puts "Meso regions: #{result.meso_regions.map(&.name)}"
puts "Macro regions: #{result.macro_regions.map(&.name)}"
puts "Mega regions: #{result.mega_regions.map(&.name)}"
puts "Subprovinces: #{result.subprovinces.map(&.name)}"
puts "Provinces: #{result.provinces.map(&.name)}"
puts "Total matched areas: #{result.total_count}"

puts "\n--- Testing route distances (#{route_points.size} points) ---"
route_result = matcher.match_route(route_points)
puts "Total route distance: #{(route_result.total_distance_meters / 1000).round(2)} km"
puts "\nTowns:"
route_result.towns.each do |t|
  puts "  #{t.area.name}: #{(t.distance_meters / 1000).round(2)} km (#{t.distance_percent.round(1)}%)"
end
puts "\nCounties:"
route_result.counties.each do |c|
  puts "  #{c.area.name}: #{(c.distance_meters / 1000).round(2)} km (#{c.distance_percent.round(1)}%)"
end
puts "\nVoivodeships:"
route_result.voivodeships.each do |v|
  puts "  #{v.area.name}: #{(v.distance_meters / 1000).round(2)} km (#{v.distance_percent.round(1)}%)"
end
puts "\nMeso regions:"
route_result.meso_regions.each do |m|
  puts "  #{m.area.name}: #{(m.distance_meters / 1000).round(2)} km (#{m.distance_percent.round(1)}%)"
end

matcher.finalize
