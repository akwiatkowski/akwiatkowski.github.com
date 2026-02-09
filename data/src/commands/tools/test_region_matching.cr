class Commands::Tools::TestRegionMatching
  def initialize(@matcher : AreaMatcher::Matcher? = nil)
  end

  def run
    matcher = @matcher || AreaMatcher::Matcher.new
    owns_matcher = @matcher.nil?

    puts "Stats: #{matcher.stats}"

    # Test single point
    puts "\n--- Testing single point (52.492, 17.206) ---"
    result = matcher.match_point(52.492009, 17.206358)
    puts "Towns: #{result.towns.map(&.name)}"
    puts "Counties: #{result.counties.map(&.name)}"
    puts "Voivodeships: #{result.voivodeships.map(&.name)}"
    puts "Meso regions: #{result.meso_regions.map(&.name)}"
    puts "Macro regions: #{result.macro_regions.map(&.name)}"

    matcher.finalize if owns_matcher
    puts "\nDone!"
  end
end
