# Spatial index for fast geographic point-in-rectangle queries.
#
# Problem:
#   GridLayer divides a map into NxM grid cells and for each cell finds
#   photos whose lat/lon falls inside that cell.  The naive approach scans
#   the entire photo array for every cell: O(cells × photos).
#   With ~25K photos and ~1K cells this means ~25M comparisons per map,
#   and some global maps have >100K cells → billions of comparisons.
#
# Solution:
#   Pre-bucket photos into a fixed-resolution grid keyed by
#   (lat_bucket, lon_bucket).  A range query only examines the
#   buckets that overlap the query rectangle — typically 1–4 buckets
#   instead of scanning all photos.
#
# Bucket resolution:
#   The default resolution (0.05°) gives ~11×7 buckets over Poland
#   (lat 49–55°, lon 14–24°).  Each bucket covers roughly 5.5 km × 3.5 km
#   at Poland's latitude.  This is coarse enough to keep the hash small
#   while fine enough that most grid-cell queries only touch 1–4 buckets.
#
# Complexity:
#   - Build:  O(n)            one pass over n photos
#   - Query:  O(b × k)        b = overlapping buckets (1–4 typical),
#                              k = photos per bucket (small)
#   - Memory: O(n)            each photo stored in exactly one bucket
#
# Usage:
#   index = Map::SpatialIndex.new(photos_with_coords, resolution: 0.05)
#   results = index.query(lat_min: 51.0, lat_max: 51.1, lon_min: 16.0, lon_max: 16.1)
#
class Map::SpatialIndex
  # Each bucket is identified by integer indices derived from floor(coord / resolution).
  alias BucketKey = Tuple(Int32, Int32)

  getter size : Int32
  getter bucket_count : Int32

  def initialize(
    photos : Array(PhotoEntity),
    @resolution : Float64 = 0.05,
  )
    @buckets = Hash(BucketKey, Array(PhotoEntity)).new
    @size = 0

    photos.each do |photo|
      next if photo.exif.not_nil!.lat.nil? || photo.exif.not_nil!.lon.nil?

      lat = photo.exif.not_nil!.lat.not_nil!
      lon = photo.exif.not_nil!.lon.not_nil!
      key = bucket_key(lat, lon)

      unless @buckets.has_key?(key)
        @buckets[key] = Array(PhotoEntity).new
      end
      @buckets[key] << photo
      @size += 1
    end

    @bucket_count = @buckets.size
  end

  # Return all photos whose lat/lon falls within the given bounding box.
  # lat_min < lat_max, lon_min < lon_max expected.
  def query(
    lat_min : Float64,
    lat_max : Float64,
    lon_min : Float64,
    lon_max : Float64,
  ) : Array(PhotoEntity)
    results = Array(PhotoEntity).new

    # Find all bucket indices that could overlap the query rectangle.
    lat_bucket_min = (lat_min / @resolution).floor.to_i
    lat_bucket_max = (lat_max / @resolution).floor.to_i
    lon_bucket_min = (lon_min / @resolution).floor.to_i
    lon_bucket_max = (lon_max / @resolution).floor.to_i

    lat_bucket_min.upto(lat_bucket_max) do |lat_i|
      lon_bucket_min.upto(lon_bucket_max) do |lon_i|
        key = {lat_i, lon_i}
        if bucket = @buckets[key]?
          bucket.each do |photo|
            photo_lat = photo.exif.not_nil!.lat.not_nil!
            photo_lon = photo.exif.not_nil!.lon.not_nil!

            if photo_lat >= lat_min && photo_lat < lat_max &&
               photo_lon >= lon_min && photo_lon < lon_max
              results << photo
            end
          end
        end
      end
    end

    results
  end

  private def bucket_key(lat : Float64, lon : Float64) : BucketKey
    {(lat / @resolution).floor.to_i, (lon / @resolution).floor.to_i}
  end
end
