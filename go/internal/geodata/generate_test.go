package geodata

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"odkrywajac/internal/model"
)

func TestBuildGeoJSON_Format(t *testing.T) {
	area := &externalArea{
		Slug: "test_town",
		Name: "Test Town",
		Polygon: [][]float64{
			{51.0, 19.0},
			{51.1, 19.0},
			{51.1, 19.1},
			{51.0, 19.1},
		},
	}

	data, err := buildGeoJSON(area, "town", 0.001)
	if err != nil {
		t.Fatalf("buildGeoJSON failed: %v", err)
	}

	// Validate structure
	if err := ValidateGeoJSONOutput(data); err != nil {
		t.Fatalf("validation failed: %v", err)
	}

	// Parse and check specific fields
	var feature geoJSONFeature
	if err := json.Unmarshal(data, &feature); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if feature.Type != "Feature" {
		t.Errorf("type = %q, want Feature", feature.Type)
	}
	if feature.Properties.Slug != "test_town" {
		t.Errorf("slug = %q, want test_town", feature.Properties.Slug)
	}
	if feature.Properties.Name != "Test Town" {
		t.Errorf("name = %q, want Test Town", feature.Properties.Name)
	}
	if feature.Properties.Type != "town" {
		t.Errorf("type = %q, want town", feature.Properties.Type)
	}
	if feature.Properties.OriginalPoints != 4 {
		t.Errorf("original_points = %d, want 4", feature.Properties.OriginalPoints)
	}
	if feature.Geometry.Type != "Polygon" {
		t.Errorf("geometry type = %q, want Polygon", feature.Geometry.Type)
	}
}

func TestBuildGeoJSON_CoordinateSwap(t *testing.T) {
	// Input: [lat, lon] = [51.5, 19.3]
	// Expected output: [lon, lat] = [19.3, 51.5]
	area := &externalArea{
		Slug: "swap_test",
		Name: "Swap Test",
		Polygon: [][]float64{
			{51.5, 19.3},
			{51.6, 19.3},
			{51.6, 19.4},
			{51.5, 19.4},
		},
	}

	data, err := buildGeoJSON(area, "town", 0)
	if err != nil {
		t.Fatalf("buildGeoJSON failed: %v", err)
	}

	var feature geoJSONFeature
	if err := json.Unmarshal(data, &feature); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	ring := feature.Geometry.Coordinates[0]
	// First point should be [lon=19.3, lat=51.5]
	if ring[0][0] != 19.3 || ring[0][1] != 51.5 {
		t.Errorf("first point = [%f, %f], want [19.3, 51.5]", ring[0][0], ring[0][1])
	}
}

func TestBuildGeoJSON_ClosedRing(t *testing.T) {
	area := &externalArea{
		Slug: "closed_test",
		Name: "Closed Test",
		Polygon: [][]float64{
			{51.0, 19.0},
			{51.1, 19.0},
			{51.1, 19.1},
		},
	}

	data, err := buildGeoJSON(area, "town", 0)
	if err != nil {
		t.Fatalf("buildGeoJSON failed: %v", err)
	}

	var feature geoJSONFeature
	if err := json.Unmarshal(data, &feature); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	ring := feature.Geometry.Coordinates[0]
	first := ring[0]
	last := ring[len(ring)-1]
	if first != last {
		t.Errorf("ring not closed: first=%v last=%v", first, last)
	}
}

func TestBuildGeoJSON_Precision(t *testing.T) {
	area := &externalArea{
		Slug: "precision_test",
		Name: "Precision",
		Polygon: [][]float64{
			{51.123456789, 19.987654321},
			{51.200000000, 19.900000000},
			{51.100000000, 19.800000000},
		},
	}

	data, err := buildGeoJSON(area, "town", 0)
	if err != nil {
		t.Fatalf("buildGeoJSON failed: %v", err)
	}

	var feature geoJSONFeature
	if err := json.Unmarshal(data, &feature); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	ring := feature.Geometry.Coordinates[0]
	// Input lat=51.123456789 → output lat=51.123457 (6 decimal places)
	// Input lon=19.987654321 → output lon=19.987654 (6 decimal places)
	if ring[0][0] != 19.987654 {
		t.Errorf("lon = %f, want 19.987654", ring[0][0])
	}
	if ring[0][1] != 51.123457 {
		t.Errorf("lat = %f, want 51.123457", ring[0][1])
	}
}

func TestBuildGeoJSON_TypeNames(t *testing.T) {
	area := &externalArea{
		Slug:    "test",
		Name:    "Test",
		Polygon: [][]float64{{51, 19}, {52, 19}, {52, 20}},
	}

	tests := []struct {
		areaType model.AreaType
		want     string
	}{
		{model.AreaTypeTown, "town"},
		{model.AreaTypeCounty, "county"},
		{model.AreaTypeVoivodeship, "voivodeship"},
		{model.AreaTypeMesoRegion, "meso_region"},
		{model.AreaTypeMacroRegion, "macro_region"},
	}

	for _, tt := range tests {
		data, err := buildGeoJSON(area, tt.areaType.String(), 0)
		if err != nil {
			t.Fatalf("buildGeoJSON for %s: %v", tt.want, err)
		}

		var feature geoJSONFeature
		if err := json.Unmarshal(data, &feature); err != nil {
			t.Fatalf("unmarshal: %v", err)
		}

		if feature.Properties.Type != tt.want {
			t.Errorf("type for %v = %q, want %q", tt.areaType, feature.Properties.Type, tt.want)
		}
	}
}

func TestCollectVisitedSlugs_FromFrontmatter(t *testing.T) {
	areas := []*model.Area{
		{Slug: "wabrzezno", Type: model.AreaTypeTown},
		{Slug: "pobiedziska", Type: model.AreaTypeTown},
		{Slug: "kujawsko-pomorskie", Type: model.AreaTypeVoivodeship},
		{Slug: "bory_tucholskie", Type: model.AreaTypeMesoRegion},
	}

	posts := []*model.Post{
		{
			Slug:      "2021-01-01-test",
			TownSlugs: []string{"wabrzezno", "kujawsko-pomorskie"},
			LandSlugs: []string{"bory_tucholskie"},
		},
	}

	visited := CollectVisitedSlugs(posts, "", areas)

	// wabrzezno should be in towns
	if !visited["towns"]["wabrzezno"] {
		t.Error("expected wabrzezno in towns")
	}
	// kujawsko-pomorskie should be in voivodeships (resolved by type)
	if !visited["voivodeships"]["kujawsko-pomorskie"] {
		t.Error("expected kujawsko-pomorskie in voivodeships")
	}
	// bory_tucholskie should be in meso_regions
	if !visited["meso_regions"]["bory_tucholskie"] {
		t.Error("expected bory_tucholskie in meso_regions")
	}
	// pobiedziska not referenced — should not be visited
	if visited["towns"]["pobiedziska"] {
		t.Error("pobiedziska should not be visited")
	}
}

func TestCollectVisitedSlugs_FromAreaCache(t *testing.T) {
	// Create a temp area cache directory with a test file
	tmpDir := t.TempDir()
	cacheContent := `---
- towns:
  - slug: gruta
  - slug: jezewo
  counties:
  - slug: grudziadzki
  meso_regions:
  - slug: pojezierze_chelminskie
  touched_towns:
  - slug: swiecie
  touched_meso_regions:
  - slug: bory_tucholskie
`
	if err := os.WriteFile(filepath.Join(tmpDir, "2021-07-18-test.yml"), []byte(cacheContent), 0o644); err != nil {
		t.Fatal(err)
	}

	posts := []*model.Post{
		{Slug: "2021-07-18-test", TownSlugs: []string{}, LandSlugs: []string{}},
	}

	visited := CollectVisitedSlugs(posts, tmpDir, nil)

	// Primary towns
	if !visited["towns"]["gruta"] {
		t.Error("expected gruta in towns")
	}
	if !visited["towns"]["jezewo"] {
		t.Error("expected jezewo in towns")
	}
	// Touched towns
	if !visited["towns"]["swiecie"] {
		t.Error("expected swiecie in towns (touched)")
	}
	// Counties
	if !visited["counties"]["grudziadzki"] {
		t.Error("expected grudziadzki in counties")
	}
	// Meso regions (primary + touched)
	if !visited["meso_regions"]["pojezierze_chelminskie"] {
		t.Error("expected pojezierze_chelminskie in meso_regions")
	}
	if !visited["meso_regions"]["bory_tucholskie"] {
		t.Error("expected bory_tucholskie in meso_regions (touched)")
	}
}

func TestCollectVisitedSlugs_MergesAdditively(t *testing.T) {
	// Area cache has gruta, frontmatter has wabrzezno — both should appear
	tmpDir := t.TempDir()
	cacheContent := `---
- towns:
  - slug: gruta
`
	if err := os.WriteFile(filepath.Join(tmpDir, "2021-01-01-test.yml"), []byte(cacheContent), 0o644); err != nil {
		t.Fatal(err)
	}

	areas := []*model.Area{
		{Slug: "wabrzezno", Type: model.AreaTypeTown},
		{Slug: "gruta", Type: model.AreaTypeTown},
	}

	posts := []*model.Post{
		{
			Slug:      "2021-01-01-test",
			TownSlugs: []string{"wabrzezno"},
			LandSlugs: []string{},
		},
	}

	visited := CollectVisitedSlugs(posts, tmpDir, areas)

	if !visited["towns"]["gruta"] {
		t.Error("expected gruta from area cache")
	}
	if !visited["towns"]["wabrzezno"] {
		t.Error("expected wabrzezno from frontmatter")
	}
}

func TestGenerate_WritesFiles(t *testing.T) {
	// Create minimal external data
	extDir := t.TempDir()
	townsYAML := `- slug: test_town
  name: Test Town
  terc: "1234"
  voivodeship: testowe
  polygon:
  - - 51.0
    - 19.0
  - - 51.1
    - 19.0
  - - 51.1
    - 19.1
  - - 51.0
    - 19.1
`
	// Write empty files for other types
	for _, at := range model.AllAreaTypes() {
		content := "[]"
		if at == model.AreaTypeTown {
			content = townsYAML
		}
		if err := os.WriteFile(filepath.Join(extDir, at.EnglishPlural()+".yaml"), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	outDir := t.TempDir()
	areas := []*model.Area{
		{Slug: "test_town", Type: model.AreaTypeTown},
	}
	posts := []*model.Post{
		{Slug: "2021-01-01-test", TownSlugs: []string{"test_town"}, LandSlugs: []string{}},
	}

	result, err := Generate(extDir, outDir, "", posts, areas, 0.001, false)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}

	if result.Generated != 1 {
		t.Errorf("generated = %d, want 1", result.Generated)
	}

	// Verify file exists and is valid GeoJSON
	outPath := filepath.Join(outDir, "towns", "test_town.json")
	data, err := os.ReadFile(outPath)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}

	if err := ValidateGeoJSONOutput(data); err != nil {
		t.Fatalf("output validation: %v", err)
	}
}

func TestGenerate_SkipsExisting(t *testing.T) {
	extDir := t.TempDir()
	townsYAML := `- slug: existing
  name: Existing
  terc: "1234"
  polygon:
  - - 51.0
    - 19.0
  - - 51.1
    - 19.0
  - - 51.1
    - 19.1
`
	for _, at := range model.AllAreaTypes() {
		content := "[]"
		if at == model.AreaTypeTown {
			content = townsYAML
		}
		if err := os.WriteFile(filepath.Join(extDir, at.EnglishPlural()+".yaml"), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	outDir := t.TempDir()
	// Pre-create the output file
	townDir := filepath.Join(outDir, "towns")
	if err := os.MkdirAll(townDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(townDir, "existing.json"), []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}

	areas := []*model.Area{{Slug: "existing", Type: model.AreaTypeTown}}
	posts := []*model.Post{{Slug: "test", TownSlugs: []string{"existing"}, LandSlugs: []string{}}}

	result, err := Generate(extDir, outDir, "", posts, areas, 0.001, false)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}

	// With polygon dir already populated, Generate skips entirely (no external load)
	if result.Generated != 0 {
		t.Errorf("generated = %d, want 0", result.Generated)
	}
}

func TestGenerate_ForceOverwritesExisting(t *testing.T) {
	extDir := t.TempDir()
	townsYAML := `- slug: existing
  name: Existing
  terc: "1234"
  polygon:
  - - 51.0
    - 19.0
  - - 51.1
    - 19.0
  - - 51.1
    - 19.1
`
	for _, at := range model.AllAreaTypes() {
		content := "[]"
		if at == model.AreaTypeTown {
			content = townsYAML
		}
		if err := os.WriteFile(filepath.Join(extDir, at.EnglishPlural()+".yaml"), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	outDir := t.TempDir()
	townDir := filepath.Join(outDir, "towns")
	if err := os.MkdirAll(townDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(townDir, "existing.json"), []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}

	areas := []*model.Area{{Slug: "existing", Type: model.AreaTypeTown}}
	posts := []*model.Post{{Slug: "test", TownSlugs: []string{"existing"}, LandSlugs: []string{}}}

	result, err := Generate(extDir, outDir, "", posts, areas, 0.001, true)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}

	if result.Generated != 1 {
		t.Errorf("generated = %d, want 1 (force should overwrite)", result.Generated)
	}
}

func TestRoundTo6(t *testing.T) {
	tests := []struct {
		input float64
		want  float64
	}{
		{19.987654321, 19.987654},
		{51.123456789, 51.123457},
		{0.0, 0.0},
		{-19.5, -19.5},
	}
	for _, tt := range tests {
		got := roundTo6(tt.input)
		if got != tt.want {
			t.Errorf("roundTo6(%f) = %f, want %f", tt.input, got, tt.want)
		}
	}
}

func TestExternalArea_Code(t *testing.T) {
	// Town with terc
	town := externalArea{Terc: "1234567"}
	if town.Code() != "1234567" {
		t.Errorf("town code = %q, want 1234567", town.Code())
	}

	// Meso region with kod
	meso := externalArea{Kod: "315.11"}
	if meso.Code() != "315.11" {
		t.Errorf("meso code = %q, want 315.11", meso.Code())
	}
}
