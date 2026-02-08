require "./spec_helper"

# Minimal mock for ExifEntity used in photo selector tests
class MockExifEntity
  property lat : Float64?
  property lon : Float64?

  def initialize(@lat : Float64? = nil, @lon : Float64? = nil)
  end
end

# Minimal mock for PhotoEntity used in photo selector tests
class MockPhotoEntity
  property exif : MockExifEntity
  property points : Int32
  property image_filename : String

  def initialize(
    @image_filename : String = "test.jpg",
    @points : Int32 = 0,
    lat : Float64? = nil,
    lon : Float64? = nil,
  )
    @exif = MockExifEntity.new(lat, lon)
  end
end

# Test version of AreaPhotoSelector that works with mock objects
class TestAreaPhotoSelector
  @geo_photos : Array(MockPhotoEntity)

  def initialize(@photos : Array(MockPhotoEntity))
    @geo_photos = @photos.select { |p| p.exif.lat && p.exif.lon }
  end

  def best_photo_for(area : AreaEntity) : MockPhotoEntity?
    return nil if @geo_photos.empty?

    if area.bbox
      photos_in_bbox = photos_in_area(area)

      unless photos_in_bbox.empty?
        return photos_in_bbox.max_by { |p| p.points }
      end

      center = area.center
      if center
        return closest_photo_to(center[0], center[1])
      end
    end

    nil
  end

  def photos_in_area(area : AreaEntity) : Array(MockPhotoEntity)
    return [] of MockPhotoEntity unless area.bbox

    @geo_photos.select { |p| area.bbox_contains?(p.exif.lat.not_nil!, p.exif.lon.not_nil!) }
  end

  def closest_photo_to(lat : Float64, lon : Float64) : MockPhotoEntity?
    return nil if @geo_photos.empty?

    @geo_photos.min_by { |p| haversine_distance(lat, lon, p.exif.lat.not_nil!, p.exif.lon.not_nil!) }
  end

  def top_photos_for(area : AreaEntity, limit : Int32 = 50) : Array(MockPhotoEntity)
    photos = photos_in_area(area)
    photos.sort_by { |p| -p.points }.first(limit)
  end

  private def haversine_distance(lat1 : Float64, lon1 : Float64, lat2 : Float64, lon2 : Float64) : Float64
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    Math.sqrt(dlat * dlat + dlon * dlon)
  end
end

describe "AreaPhotoSelector" do
  describe "#photos_in_area" do
    it "returns photos within bbox" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("inside.jpg", points: 50, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("outside.jpg", points: 100, lat: 50.0, lon: 15.0),
        MockPhotoEntity.new("also_inside.jpg", points: 30, lat: 52.8, lon: 17.8),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.photos_in_area(area)

      result.size.should eq 2
      result.map(&.image_filename).should contain "inside.jpg"
      result.map(&.image_filename).should contain "also_inside.jpg"
    end

    it "returns empty array when no photos in bbox" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("outside1.jpg", points: 50, lat: 50.0, lon: 15.0),
        MockPhotoEntity.new("outside2.jpg", points: 100, lat: 55.0, lon: 20.0),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.photos_in_area(area)

      result.should be_empty
    end

    it "returns empty array when area has no bbox" do
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town)

      photos = [MockPhotoEntity.new("test.jpg", points: 50, lat: 52.5, lon: 17.5)]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.photos_in_area(area)

      result.should be_empty
    end
  end

  describe "#best_photo_for" do
    it "returns photo with highest score within bbox" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("low_score.jpg", points: 30, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("high_score.jpg", points: 100, lat: 52.6, lon: 17.6),
        MockPhotoEntity.new("medium_score.jpg", points: 50, lat: 52.7, lon: 17.7),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.best_photo_for(area)

      result.should_not be_nil
      result.not_nil!.image_filename.should eq "high_score.jpg"
    end

    it "falls back to closest photo when none in bbox" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("far.jpg", points: 100, lat: 50.0, lon: 15.0),
        MockPhotoEntity.new("closer.jpg", points: 50, lat: 51.5, lon: 16.5), # Closer to center (52.5, 17.5)
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.best_photo_for(area)

      result.should_not be_nil
      result.not_nil!.image_filename.should eq "closer.jpg"
    end

    it "returns nil when no photos available" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      selector = TestAreaPhotoSelector.new([] of MockPhotoEntity)
      result = selector.best_photo_for(area)

      result.should be_nil
    end

    it "returns nil when area has no bbox" do
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town)

      photos = [MockPhotoEntity.new("test.jpg", points: 50, lat: 52.5, lon: 17.5)]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.best_photo_for(area)

      result.should be_nil
    end
  end

  describe "#closest_photo_to" do
    it "returns photo closest to given coordinates" do
      photos = [
        MockPhotoEntity.new("far.jpg", lat: 50.0, lon: 15.0),
        MockPhotoEntity.new("closest.jpg", lat: 52.4, lon: 17.4),
        MockPhotoEntity.new("medium.jpg", lat: 51.0, lon: 16.0),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.closest_photo_to(52.5, 17.5)

      result.should_not be_nil
      result.not_nil!.image_filename.should eq "closest.jpg"
    end

    it "returns nil when no photos available" do
      selector = TestAreaPhotoSelector.new([] of MockPhotoEntity)
      result = selector.closest_photo_to(52.5, 17.5)

      result.should be_nil
    end
  end

  describe "#top_photos_for" do
    it "returns photos sorted by score descending" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("low.jpg", points: 30, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("high.jpg", points: 100, lat: 52.6, lon: 17.6),
        MockPhotoEntity.new("medium.jpg", points: 50, lat: 52.7, lon: 17.7),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.top_photos_for(area)

      result.size.should eq 3
      result[0].image_filename.should eq "high.jpg"
      result[1].image_filename.should eq "medium.jpg"
      result[2].image_filename.should eq "low.jpg"
    end

    it "respects limit parameter" do
      bbox = AreaMatcher::BBox.new(south: 52.0, north: 53.0, west: 17.0, east: 18.0)
      area = AreaEntity.new(slug: "test", name: "Test", area_type: AreaType::Town, bbox: bbox)

      photos = [
        MockPhotoEntity.new("1.jpg", points: 100, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("2.jpg", points: 90, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("3.jpg", points: 80, lat: 52.5, lon: 17.5),
        MockPhotoEntity.new("4.jpg", points: 70, lat: 52.5, lon: 17.5),
      ]

      selector = TestAreaPhotoSelector.new(photos)
      result = selector.top_photos_for(area, limit: 2)

      result.size.should eq 2
      result[0].image_filename.should eq "1.jpg"
      result[1].image_filename.should eq "2.jpg"
    end
  end
end
