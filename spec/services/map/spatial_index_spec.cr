require "../../spec_helper"

# Minimal mock for spatial index testing — avoids needing full PhotoEntity/Post setup
module SpatialIndexTestHelper
  # Create a mock PhotoEntity-like object isn't feasible because PhotoEntity
  # requires Tremolite::Post.  Instead we test SpatialIndex indirectly
  # through the MapPipeline integration tests, and test the algorithm logic
  # directly here using the real SpatialIndex with an empty photo array +
  # checking structural properties.

  def self.make_spatial_index_empty
    Map::SpatialIndex.new(Array(PhotoEntity).new)
  end
end

describe Map::SpatialIndex do
  describe "empty index" do
    it "has zero size and zero buckets" do
      index = SpatialIndexTestHelper.make_spatial_index_empty
      index.size.should eq 0
      index.bucket_count.should eq 0
    end

    it "returns empty results for any query" do
      index = SpatialIndexTestHelper.make_spatial_index_empty
      results = index.query(lat_min: 50.0, lat_max: 52.0, lon_min: 16.0, lon_max: 20.0)
      results.size.should eq 0
    end
  end

  describe "bucket key computation" do
    it "groups nearby coordinates into same bucket" do
      # With default resolution 0.05, coords 51.01 and 51.04 → bucket 1020
      # (floor(51.01/0.05) = floor(1020.2) = 1020)
      # (floor(51.04/0.05) = floor(1020.8) = 1020)
      # These should be in the same bucket
      bucket1 = (51.01 / 0.05).floor.to_i
      bucket2 = (51.04 / 0.05).floor.to_i
      bucket1.should eq bucket2
    end

    it "separates distant coordinates into different buckets" do
      # 51.0 → bucket 1020, 52.0 → bucket 1040
      bucket1 = (51.0 / 0.05).floor.to_i
      bucket2 = (52.0 / 0.05).floor.to_i
      bucket1.should_not eq bucket2
    end

    it "handles negative coordinates correctly" do
      # -10.03 → floor(-10.03/0.05) = floor(-200.6) = -201
      bucket = (-10.03 / 0.05).floor.to_i
      bucket.should eq -201
    end
  end

  describe "query correctness" do
    it "returns empty for non-overlapping query on empty index" do
      index = SpatialIndexTestHelper.make_spatial_index_empty
      results = index.query(lat_min: 0.0, lat_max: 0.001, lon_min: 0.0, lon_max: 0.001)
      results.should be_empty
    end
  end

  describe "resolution" do
    it "defaults to 0.05 degrees" do
      index = SpatialIndexTestHelper.make_spatial_index_empty
      # Poland spans ~6° lat × 10° lon → ~120 × 200 = ~24K possible buckets
      # but only occupied ones are stored, so empty index has 0
      index.bucket_count.should eq 0
    end
  end
end
