require "../spec_helper"
require "../../data/src/services/area_matcher/area"

TERC_TYPE_LABELS = {
  '1' => "miejska",
  '2' => "wiejska",
  '3' => "miejsko-wiejska",
}

def make_test_area(slug : String, voivodeship : String? = nil, terc : String? = nil) : AreaMatcher::Area
  AreaMatcher::Area.new(
    slug: slug,
    name: slug.capitalize,
    area_type: AreaMatcher::AreaType::Town,
    coords: [] of Array(Float64),
    voivodeship: voivodeship,
    terc: terc,
  )
end

# Extracted two-pass disambiguation logic matching GenerateAreasForPosts#disambiguate_slugs!
def disambiguate_slugs!(areas : Array(AreaMatcher::Area))
  # Pass 1: voivodeship
  by_slug = areas.group_by(&.slug)
  pass1 = 0
  by_slug.each do |slug, entries|
    next if entries.size == 1
    entries.each do |area|
      if voiv = area.voivodeship
        area.slug = "#{slug}-#{voiv}"
        pass1 += 1
      end
    end
  end
  # Pass 2: type label for remaining collisions
  by_slug2 = areas.group_by(&.slug)
  pass2 = 0
  by_slug2.each do |slug, entries|
    next if entries.size == 1
    type_digits = entries.map { |a| a.terc.try { |t| t[-1] } }
    types_unique = type_digits.compact.uniq.size == entries.size

    entries.each do |area|
      terc = area.terc
      next unless terc
      if types_unique
        label = TERC_TYPE_LABELS[terc[-1]]? || terc
        area.slug = "#{slug}-#{label}"
      else
        area.slug = "#{slug}-#{terc}"
      end
      pass2 += 1
    end
  end
  pass1 + pass2
end

describe "disambiguate_slugs!" do
  it "leaves unique slugs unchanged" do
    areas = [
      make_test_area("poznan", "wielkopolskie"),
      make_test_area("krakow", "malopolskie"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "poznan"
    areas[1].slug.should eq "krakow"
  end

  it "disambiguates two areas with same slug by appending voivodeship" do
    areas = [
      make_test_area("wasosz", "dolnoslaskie"),
      make_test_area("wasosz", "podlaskie"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "wasosz-dolnoslaskie"
    areas[1].slug.should eq "wasosz-podlaskie"
  end

  it "disambiguates three areas with same slug" do
    areas = [
      make_test_area("lipno", "kujawsko-pomorskie"),
      make_test_area("lipno", "lodzkie"),
      make_test_area("lipno", "mazowieckie"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "lipno-kujawsko-pomorskie"
    areas[1].slug.should eq "lipno-lodzkie"
    areas[2].slug.should eq "lipno-mazowieckie"
  end

  it "leaves area without voivodeship unchanged on duplicate slug" do
    areas = [
      make_test_area("test", nil),
      make_test_area("test", "wielkopolskie"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "test"
    areas[1].slug.should eq "test-wielkopolskie"
  end

  it "returns the number of collisions fixed" do
    areas = [
      make_test_area("wasosz", "dolnoslaskie"),
      make_test_area("wasosz", "podlaskie"),
      make_test_area("poznan", "wielkopolskie"),
    ]
    count = disambiguate_slugs!(areas)
    count.should eq 2
  end

  it "returns 0 when no collisions" do
    areas = [
      make_test_area("poznan", "wielkopolskie"),
      make_test_area("krakow", "malopolskie"),
    ]
    count = disambiguate_slugs!(areas)
    count.should eq 0
  end

  it "disambiguates urban/rural pairs with miejska/wiejska labels" do
    areas = [
      make_test_area("bartoszyce", "warminsko-mazurskie", terc: "2801011"),
      make_test_area("bartoszyce", "warminsko-mazurskie", terc: "2801032"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "bartoszyce-warminsko-mazurskie-miejska"
    areas[1].slug.should eq "bartoszyce-warminsko-mazurskie-wiejska"
  end

  it "handles mixed cross-voivodeship and same-voivodeship collisions" do
    areas = [
      make_test_area("lipno", "kujawsko-pomorskie", terc: "0408011"),
      make_test_area("lipno", "kujawsko-pomorskie", terc: "0408062"),
      make_test_area("lipno", "lodzkie", terc: "1099011"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "lipno-kujawsko-pomorskie-miejska"
    areas[1].slug.should eq "lipno-kujawsko-pomorskie-wiejska"
    areas[2].slug.should eq "lipno-lodzkie"
  end

  it "falls back to TERC when type digits collide (same type, different county)" do
    areas = [
      make_test_area("czarna", "podkarpackie", terc: "1810032"),
      make_test_area("czarna", "podkarpackie", terc: "1801032"),
      make_test_area("czarna", "podkarpackie", terc: "1803032"),
    ]
    disambiguate_slugs!(areas)
    areas[0].slug.should eq "czarna-podkarpackie-1810032"
    areas[1].slug.should eq "czarna-podkarpackie-1801032"
    areas[2].slug.should eq "czarna-podkarpackie-1803032"
  end
end

describe "slug disambiguation integration" do
  it "data/external/towns.yaml has duplicate slugs" do
    data = YAML.parse(File.read("data/external/towns.yaml"))
    slugs = data.as_a.map { |item| item["slug"].as_s }
    duplicates = slugs.group_by { |s| s }.select { |_, v| v.size > 1 }
    duplicates.size.should be > 0
  end

  it "data/config/areas/towns.yml has no duplicate slugs" do
    data = YAML.parse(File.read("data/config/areas/towns.yml"))
    slugs = data.as_a.map { |item| item["slug"].as_s }
    duplicates = slugs.group_by { |s| s }.select { |_, v| v.size > 1 }
    duplicates.should be_empty
  end

  it "disambiguated slugs in config start with original slug plus voivodeship" do
    external = YAML.parse(File.read("data/external/towns.yaml"))
    external_slugs = external.as_a.map { |item| item["slug"].as_s }
    colliding_slugs = external_slugs.group_by { |s| s }.select { |_, v| v.size > 1 }.keys

    config = YAML.parse(File.read("data/config/areas/towns.yml"))
    config_slugs = config.as_a.map { |item| item["slug"].as_s }

    colliding_slugs.each do |slug|
      external_entries = external.as_a.select { |item| item["slug"].as_s == slug }

      external_entries.each do |ext_entry|
        voiv = ext_entry["voivodeship"].as_s
        prefix = "#{slug}-#{voiv}"
        match = config_slugs.find { |cs| cs.starts_with?(prefix) }
        match.should_not be_nil, "Expected config slug starting with '#{prefix}'"
      end
    end
  end
end
