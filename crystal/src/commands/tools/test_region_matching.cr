class Commands::Tools::TestRegionMatching
  def initialize(@matcher : AreaMatcher::Matcher? = nil)
  end

  def run
    matcher = @matcher || AreaMatcher::Matcher.new
    owns_matcher = @matcher.nil?

    puts "Stats: #{matcher.stats}"

    # Test single point — Gniezno's Rynek, a public landmark that sits inside
    # overlapping town, county, voivodeship and region polygons, so every
    # matcher level returns something and a silent regression is visible.
    puts "\n--- Testing single point (Gniezno, Rynek) ---"
    result = matcher.match_point(52.534800, 17.592600)
    puts "Towns: #{result.towns.map(&.name)}"
    puts "Counties: #{result.counties.map(&.name)}"
    puts "Voivodeships: #{result.voivodeships.map(&.name)}"
    puts "Meso regions: #{result.meso_regions.map(&.name)}"
    puts "Macro regions: #{result.macro_regions.map(&.name)}"

    matcher.finalize if owns_matcher
    puts "\nDone!"
  end
end
