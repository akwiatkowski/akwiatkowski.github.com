require "json"
require "yaml"
require "file_utils"
require "log"
require "../crystal/src/services/area_matcher/all"
require "../crystal/src/commands/pipeline/generate_polygon_json"

tolerance = 0.001
force = false

ARGV.each do |arg|
  if arg.starts_with?("--tolerance=")
    tolerance = arg.split("=")[1].to_f
  elsif arg == "--force" || arg == "-f"
    force = true
  elsif arg == "--help" || arg == "-h"
    puts "Usage: crystal run commands/generate_polygon_json.cr [options]"
    puts ""
    puts "Options:"
    puts "  --tolerance=N   Douglas-Peucker tolerance in degrees (default: 0.001)"
    puts "  --force, -f     Regenerate all files (default: skip existing)"
    puts "  --help, -h      Show this help"
    exit 0
  end
end

command = Commands::Pipeline::GeneratePolygonJson.new(tolerance: tolerance, force: force)
command.run
