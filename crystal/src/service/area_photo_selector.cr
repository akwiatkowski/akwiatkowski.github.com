require "../model/area_entity"
require "../model/photo_entity"

# Selects the best photo for an area based on bbox intersection and PhotoTags scoring
# Falls back to closest photo if none found within bbox
class AreaPhotoSelector
  Log = ::Log.for(self)

  @geo_photos : Array(PhotoEntity)
  @used_photos : Set(String)

  def initialize(@photos : Array(PhotoEntity))
    # Filter to only photos with valid coordinates
    @geo_photos = @photos.select { |p| p.exif.lat && p.exif.lon }
    @used_photos = Set(String).new
    Log.debug { "AreaPhotoSelector initialized with #{@geo_photos.size} geo-tagged photos (out of #{@photos.size} total)" }
  end

  # Find best photo for an area
  # 1. Try photos within bbox, select by highest PhotoTags score
  # 2. If none in bbox, find closest photo to bbox center
  def best_photo_for(area : AreaEntity) : PhotoEntity?
    return nil if @geo_photos.empty?

    # Try bbox-based selection first
    if area.bbox
      photos_in_bbox = photos_in_area(area)

      unless photos_in_bbox.empty?
        # Return photo with highest score (points from PhotoTags)
        return photos_in_bbox.max_by { |p| p.points }
      end

      # Fallback: find closest photo to bbox center
      center = area.center
      if center
        return closest_photo_to(center[0], center[1])
      end
    end

    # No bbox, can't select
    nil
  end

  # Find best photo that hasn't been used by another area yet.
  # Marks the selected photo as used so subsequent calls return different photos.
  def best_unique_photo_for(area : AreaEntity) : PhotoEntity?
    return nil if @geo_photos.empty?

    if area.bbox
      candidates = photos_in_area(area)
        .sort_by { |p| -p.points }

      candidates.each do |photo|
        unless @used_photos.includes?(photo.image_filename)
          @used_photos.add(photo.image_filename)
          return photo
        end
      end

      # All bbox photos used — fallback to closest unused
      center = area.center
      if center
        sorted = @geo_photos
          .reject { |p| @used_photos.includes?(p.image_filename) }
          .sort_by { |p| euclidean_distance_approx(center[0], center[1], p.exif.lat.not_nil!, p.exif.lon.not_nil!) }
        if photo = sorted.first?
          @used_photos.add(photo.image_filename)
          return photo
        end
      end
    end

    nil
  end

  # Get all photos within area's bounding box
  def photos_in_area(area : AreaEntity) : Array(PhotoEntity)
    return [] of PhotoEntity unless area.bbox

    @geo_photos.select { |p| area.bbox_contains?(p.exif.lat.not_nil!, p.exif.lon.not_nil!) }
  end

  # Find photo closest to given coordinates
  def closest_photo_to(lat : Float64, lon : Float64) : PhotoEntity?
    return nil if @geo_photos.empty?

    @geo_photos.min_by { |p| euclidean_distance_approx(lat, lon, p.exif.lat.not_nil!, p.exif.lon.not_nil!) }
  end

  # Get top N photos for an area (for gallery)
  # Sorted by PhotoTags score (highest first)
  def top_photos_for(area : AreaEntity, limit : Int32 = 50) : Array(PhotoEntity)
    photos = photos_in_area(area)
    photos.sort_by { |p| -p.points }.first(limit)
  end

  # Euclidean distance approximation (returns distance in degrees)
  # Good enough for relative comparisons within Poland
  private def euclidean_distance_approx(lat1 : Float64, lon1 : Float64, lat2 : Float64, lon2 : Float64) : Float64
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    Math.sqrt(dlat * dlat + dlon * dlon)
  end
end

# Result struct for caching best photos per area
struct AreaPhotoResult
  getter area_slug : String
  getter area_type : AreaType
  getter photo_path : String?
  getter post_slug : String?
  getter score : Int32

  def initialize(
    @area_slug : String,
    @area_type : AreaType,
    @photo_path : String? = nil,
    @post_slug : String? = nil,
    @score : Int32 = 0,
  )
  end

  def has_photo? : Bool
    !@photo_path.nil?
  end
end
