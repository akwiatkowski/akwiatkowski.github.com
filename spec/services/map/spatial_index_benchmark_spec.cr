require "../../spec_helper"

# Benchmark comparing linear scan vs SpatialIndex for grid photo selection.
#
# We can't easily create 25K PhotoEntity objects (they require Tremolite::Post),
# so this benchmark operates at the algorithm level: we simulate the two approaches
# using raw Float64 coordinate arrays and measure the difference.
#
# The benchmark proves the O(cells × n) vs O(cells × bucket_avg) difference
# that the SpatialIndex provides in production.

# Simulated photo coordinate (lat, lon)
alias SimCoord = Tuple(Float64, Float64)

# Linear scan: for each query, scan all coords
def linear_scan_query(
  all_coords : Array(SimCoord),
  lat_min : Float64, lat_max : Float64,
  lon_min : Float64, lon_max : Float64,
) : Int32
  count = 0
  all_coords.each do |coord|
    lat, lon = coord
    if lat >= lat_min && lat < lat_max && lon >= lon_min && lon < lon_max
      count += 1
    end
  end
  count
end

# Spatial index simulation: hash-bucketed coords
class SimSpatialIndex
  RESOLUTION = 0.05

  def initialize(@coords : Array(SimCoord))
    @buckets = Hash(Tuple(Int32, Int32), Array(SimCoord)).new
    @coords.each do |coord|
      lat, lon = coord
      key = {(lat / RESOLUTION).floor.to_i, (lon / RESOLUTION).floor.to_i}
      @buckets[key] ||= Array(SimCoord).new
      @buckets[key] << coord
    end
  end

  def query(lat_min : Float64, lat_max : Float64, lon_min : Float64, lon_max : Float64) : Int32
    count = 0
    lat_b_min = (lat_min / RESOLUTION).floor.to_i
    lat_b_max = (lat_max / RESOLUTION).floor.to_i
    lon_b_min = (lon_min / RESOLUTION).floor.to_i
    lon_b_max = (lon_max / RESOLUTION).floor.to_i

    lat_b_min.upto(lat_b_max) do |lat_i|
      lon_b_min.upto(lon_b_max) do |lon_i|
        if bucket = @buckets[{lat_i, lon_i}]?
          bucket.each do |coord|
            lat, lon = coord
            if lat >= lat_min && lat < lat_max && lon >= lon_min && lon < lon_max
              count += 1
            end
          end
        end
      end
    end
    count
  end
end

describe "SpatialIndex Benchmark" do
  # Generate synthetic photo coordinates scattered across Poland
  # (lat 49-55, lon 14-24)
  photo_count = 25_000
  coords = Array(SimCoord).new(photo_count)
  rng = Random.new(42) # deterministic seed for reproducibility
  photo_count.times do
    lat = 49.0 + rng.rand * 6.0  # 49-55
    lon = 14.0 + rng.rand * 10.0 # 14-24
    coords << {lat, lon}
  end

  # Simulate grid cells for a zoom-8 map with photo_size=160
  # Poland at zoom 8 is roughly 15×10 tiles = 3840×2560 px
  # With photo_size=160: 24×16 = 384 cells
  cell_count_x = 24
  cell_count_y = 16
  lat_range = {49.0, 55.0}
  lon_range = {14.0, 24.0}
  lat_step = (lat_range[1] - lat_range[0]) / cell_count_y
  lon_step = (lon_range[1] - lon_range[0]) / cell_count_x

  cells = Array(Tuple(Float64, Float64, Float64, Float64)).new
  cell_count_y.times do |cy|
    cell_count_x.times do |cx|
      lat_min = lat_range[0] + cy * lat_step
      lat_max = lat_min + lat_step
      lon_min = lon_range[0] + cx * lon_step
      lon_max = lon_min + lon_step
      cells << {lat_min, lat_max, lon_min, lon_max}
    end
  end

  it "linear scan and spatial index produce identical results" do
    index = SimSpatialIndex.new(coords)

    cells.each do |cell|
      lat_min, lat_max, lon_min, lon_max = cell
      linear_count = linear_scan_query(coords, lat_min, lat_max, lon_min, lon_max)
      spatial_count = index.query(lat_min, lat_max, lon_min, lon_max)
      spatial_count.should eq(linear_count),
        "Mismatch at cell (#{lat_min},#{lon_min})-(#{lat_max},#{lon_max}): " \
        "linear=#{linear_count} spatial=#{spatial_count}"
    end
  end

  it "spatial index is faster than linear scan" do
    index = SimSpatialIndex.new(coords)

    # Measure linear scan
    linear_start = Time.instant
    total_linear = 0
    cells.each do |cell|
      lat_min, lat_max, lon_min, lon_max = cell
      total_linear += linear_scan_query(coords, lat_min, lat_max, lon_min, lon_max)
    end
    linear_elapsed = Time.instant - linear_start

    # Measure spatial index
    spatial_start = Time.instant
    total_spatial = 0
    cells.each do |cell|
      lat_min, lat_max, lon_min, lon_max = cell
      total_spatial += index.query(lat_min, lat_max, lon_min, lon_max)
    end
    spatial_elapsed = Time.instant - spatial_start

    # Results should match
    total_spatial.should eq total_linear

    speedup = linear_elapsed.total_milliseconds / spatial_elapsed.total_milliseconds

    if ENV["BENCH"]?
      puts ""
      puts "  ┌─────────────────────────────────────────────────────┐"
      puts "  │ SpatialIndex Benchmark Results                      │"
      puts "  ├─────────────────────────────────────────────────────┤"
      puts "  │ Photos: #{photo_count.to_s.rjust(10)}                             │"
      puts "  │ Grid cells: #{cells.size.to_s.rjust(7)}                             │"
      puts "  │ Comparisons (linear): #{(photo_count.to_i64 * cells.size).to_s.rjust(12)}           │"
      puts "  │                                                     │"
      puts "  │ Linear scan:    #{linear_elapsed.total_milliseconds.round(2).to_s.rjust(8)} ms                      │"
      puts "  │ Spatial index:  #{spatial_elapsed.total_milliseconds.round(2).to_s.rjust(8)} ms                      │"
      puts "  │ Speedup:        #{speedup.round(1).to_s.rjust(8)}x                      │"
      puts "  │ Found photos:   #{total_linear.to_s.rjust(8)}                        │"
      puts "  └─────────────────────────────────────────────────────┘"
      puts ""
    end

    # Spatial index should be at least 5x faster for this workload
    speedup.should be > 5.0
  end

  it "spatial index scales well with more cells (zoom 10 scenario)" do
    # Zoom 10: ~60×40 tiles = 15360×10240 px, photo_size=50 → 307×205 ≈ 62K cells
    # This is the "detailed" global map — worst case for linear scan
    fine_cell_count_x = 307
    fine_cell_count_y = 205
    fine_lat_step = (lat_range[1] - lat_range[0]) / fine_cell_count_y
    fine_lon_step = (lon_range[1] - lon_range[0]) / fine_cell_count_x

    fine_cells = Array(Tuple(Float64, Float64, Float64, Float64)).new
    fine_cell_count_y.times do |cy|
      fine_cell_count_x.times do |cx|
        lat_min = lat_range[0] + cy * fine_lat_step
        lat_max = lat_min + fine_lat_step
        lon_min = lon_range[0] + cx * fine_lon_step
        lon_max = lon_min + fine_lon_step
        fine_cells << {lat_min, lat_max, lon_min, lon_max}
      end
    end

    index = SimSpatialIndex.new(coords)

    # Measure linear scan (only first 1000 cells to avoid test timeout)
    sample_cells = fine_cells[0...1000]

    linear_start = Time.instant
    sample_cells.each do |cell|
      lat_min, lat_max, lon_min, lon_max = cell
      linear_scan_query(coords, lat_min, lat_max, lon_min, lon_max)
    end
    linear_per_cell = (Time.instant - linear_start).total_microseconds / sample_cells.size

    spatial_start = Time.instant
    sample_cells.each do |cell|
      lat_min, lat_max, lon_min, lon_max = cell
      index.query(lat_min, lat_max, lon_min, lon_max)
    end
    spatial_per_cell = (Time.instant - spatial_start).total_microseconds / sample_cells.size

    linear_total_est = linear_per_cell * fine_cells.size / 1000.0
    spatial_total_est = spatial_per_cell * fine_cells.size / 1000.0
    speedup = linear_per_cell / spatial_per_cell

    if ENV["BENCH"]?
      puts ""
      puts "  ┌─────────────────────────────────────────────────────┐"
      puts "  │ Fine Grid Benchmark (zoom 10, photo_size=50)        │"
      puts "  ├─────────────────────────────────────────────────────┤"
      puts "  │ Photos: #{photo_count.to_s.rjust(10)}                             │"
      puts "  │ Grid cells: #{fine_cells.size.to_s.rjust(7)}                             │"
      puts "  │                                                     │"
      puts "  │ Per cell (linear):  #{linear_per_cell.round(2).to_s.rjust(8)} µs                   │"
      puts "  │ Per cell (spatial): #{spatial_per_cell.round(2).to_s.rjust(8)} µs                   │"
      puts "  │ Speedup:            #{speedup.round(1).to_s.rjust(8)}x                   │"
      puts "  │                                                     │"
      puts "  │ Est. total (linear):  #{linear_total_est.round(1).to_s.rjust(8)} ms                 │"
      puts "  │ Est. total (spatial): #{spatial_total_est.round(1).to_s.rjust(8)} ms                 │"
      puts "  └─────────────────────────────────────────────────────┘"
      puts ""
    end

    # Fine grid should show even bigger speedup
    speedup.should be > 10.0
  end
end
