require "./spec_helper"

# Mock post for testing area methods
class MockPostWithAreas
  property towns : Array(String)
  property lands : Array(String)
  property slug : String

  @_area_associations : Hash(AreaType, Array(AreaAssociation))?

  def initialize(@slug : String = "test-post")
    @towns = [] of String
    @lands = [] of String
  end

  # Simulate area_slugs method from Post
  def area_slugs(type : AreaType) : Array(String)
    slugs = Set(String).new

    case type
    when AreaType::Town
      @towns.each { |s| slugs << s }
    when AreaType::MesoRegion
      @lands.each { |s| slugs << s }
    when AreaType::Voivodeship
      @towns.each { |s| slugs << s }
    end

    # Add calculated slugs
    if @_area_associations
      @_area_associations.not_nil![type]?.try(&.each { |a| slugs << a.slug })
    end

    slugs.to_a
  end

  def was_in_area?(area : AreaEntity) : Bool
    area_slugs(area.area_type).includes?(area.slug)
  end

  def was_in_area?(type : AreaType, slug : String) : Bool
    area_slugs(type).includes?(slug)
  end

  def set_area_associations(associations : Hash(AreaType, Array(AreaAssociation)))
    @_area_associations = associations
  end
end

describe "Post area methods" do
  describe "#area_slugs" do
    it "returns manual town slugs" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska", "swarzedz"]

      slugs = post.area_slugs(AreaType::Town)
      slugs.should contain "pobiedziska"
      slugs.should contain "swarzedz"
    end

    it "returns manual land slugs as meso_regions" do
      post = MockPostWithAreas.new
      post.lands = ["pojezierze_gnieznienskie"]

      slugs = post.area_slugs(AreaType::MesoRegion)
      slugs.should contain "pojezierze_gnieznienskie"
    end

    it "combines manual and calculated slugs" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      # Simulate calculated association
      associations = {
        AreaType::Town => [
          AreaAssociation.new(
            slug: "swarzedz",
            name: "Swarzędz",
            area_type: AreaType::Town,
            distance_meters: 3000.0,
            distance_percent: 15.0
          ),
        ],
      } of AreaType => Array(AreaAssociation)
      post.set_area_associations(associations)

      slugs = post.area_slugs(AreaType::Town)
      slugs.should contain "pobiedziska" # manual
      slugs.should contain "swarzedz"    # calculated
    end

    it "deduplicates when same slug in manual and calculated" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      associations = {
        AreaType::Town => [
          AreaAssociation.new(
            slug: "pobiedziska",
            name: "Pobiedziska",
            area_type: AreaType::Town,
            distance_meters: 5000.0,
            distance_percent: 80.0
          ),
        ],
      } of AreaType => Array(AreaAssociation)
      post.set_area_associations(associations)

      slugs = post.area_slugs(AreaType::Town)
      slugs.count("pobiedziska").should eq 1
    end

    it "returns empty array for types without data" do
      post = MockPostWithAreas.new

      slugs = post.area_slugs(AreaType::County)
      slugs.should be_empty
    end
  end

  describe "#was_in_area? with AreaEntity" do
    it "returns true when post was in area" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      area = AreaEntity.new(
        slug: "pobiedziska",
        name: "Pobiedziska",
        area_type: AreaType::Town
      )

      post.was_in_area?(area).should be_true
    end

    it "returns false when post was not in area" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      area = AreaEntity.new(
        slug: "gniezno",
        name: "Gniezno",
        area_type: AreaType::Town
      )

      post.was_in_area?(area).should be_false
    end
  end

  describe "#was_in_area? with type and slug" do
    it "returns true when post was in area" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      post.was_in_area?(AreaType::Town, "pobiedziska").should be_true
    end

    it "returns false when post was not in area" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]

      post.was_in_area?(AreaType::Town, "gniezno").should be_false
    end

    it "checks correct type" do
      post = MockPostWithAreas.new
      post.towns = ["pobiedziska"]
      post.lands = ["pojezierze_gnieznienskie"]

      post.was_in_area?(AreaType::Town, "pobiedziska").should be_true
      post.was_in_area?(AreaType::MesoRegion, "pobiedziska").should be_false
      post.was_in_area?(AreaType::MesoRegion, "pojezierze_gnieznienskie").should be_true
    end
  end
end
