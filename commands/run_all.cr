require "json"
require "yaml"
require "file_utils"
require "log"
require "../crystal/src/framework/tremolite"
require "../crystal/src/blog"
require "../crystal/src/service/area_matcher/all"
require "../crystal/src/commands/pipeline/all"

# Run all pipeline commands in order with a shared AreaMatcher::Matcher.
# This avoids loading ~90MB polygon data 3 times.
#
# Pipeline order:
#   1. generate_areas_for_posts  (route → area cache)
#   2. generate_polygon_json     (area cache → polygon GeoJSON)
#   3. assign_photos_to_areas    (photos → area photo cache)
#   4. gpx_rectify               (raw GPX → processed GPX, no matcher needed)

overwrite = ARGV.includes?("--overwrite") || ARGV.includes?("-f")

puts "=== Loading shared AreaMatcher ==="
matcher = AreaMatcher::Matcher.new
puts "Stats: #{matcher.stats}"

puts "\n" + "=" * 60
puts "=== Step 1/4: Generate areas for posts ==="
puts "=" * 60
Commands::Pipeline::GenerateAreasForPosts.new(overwrite: overwrite, matcher: matcher).run

puts "\n" + "=" * 60
puts "=== Step 2/4: Generate polygon JSON ==="
puts "=" * 60
Commands::Pipeline::GeneratePolygonJson.new(force: overwrite, matcher: matcher).run

puts "\n" + "=" * 60
puts "=== Step 3/4: Assign photos to areas ==="
puts "=" * 60
Commands::Pipeline::AssignPhotosToAreas.new(overwrite: overwrite, matcher: matcher).run

puts "\n" + "=" * 60
puts "=== Step 4/4: GPX rectify ==="
puts "=" * 60
Commands::Pipeline::GpxRectify.new.run

matcher.finalize

puts "\n" + "=" * 60
puts "=== All pipeline commands complete ==="
puts "=" * 60
