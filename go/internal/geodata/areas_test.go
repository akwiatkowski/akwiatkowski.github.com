package geodata

import (
	"os"
	"path/filepath"
	"testing"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

func TestNormalizeCoordOrder_LatLon(t *testing.T) {
	// Input: [lat, lon] — typical for admin areas (lat ~51 for Poland)
	coords := [][]float64{
		{51.0, 19.0},
		{51.1, 19.1},
	}

	result := normalizeCoordOrder(coords)

	// Should be swapped to [lon, lat]
	if result[0][0] != 19.0 || result[0][1] != 51.0 {
		t.Errorf("expected [19.0, 51.0], got %v", result[0])
	}
}

func TestNormalizeCoordOrder_LonLat(t *testing.T) {
	// Input: [lon, lat] — typical for geographic regions (lon ~20 for Poland)
	coords := [][]float64{
		{20.0, 51.0},
		{20.1, 51.1},
	}

	result := normalizeCoordOrder(coords)

	// Should NOT be swapped
	if result[0][0] != 20.0 || result[0][1] != 51.0 {
		t.Errorf("expected [20.0, 51.0], got %v", result[0])
	}
}

func TestNormalizeCoordOrder_Empty(t *testing.T) {
	result := normalizeCoordOrder(nil)
	if len(result) != 0 {
		t.Errorf("expected empty, got %v", result)
	}
}

func TestComputeBBox(t *testing.T) {
	// [lon, lat] order
	coords := [][]float64{
		{19.0, 51.0},
		{19.5, 51.5},
		{20.0, 51.0},
		{19.5, 50.5},
	}

	bbox := computeBBox(coords)

	if bbox.South != 50.5 {
		t.Errorf("south = %f, want 50.5", bbox.South)
	}
	if bbox.North != 51.5 {
		t.Errorf("north = %f, want 51.5", bbox.North)
	}
	if bbox.West != 19.0 {
		t.Errorf("west = %f, want 19.0", bbox.West)
	}
	if bbox.East != 20.0 {
		t.Errorf("east = %f, want 20.0", bbox.East)
	}
}

func TestComputeBBox_Empty(t *testing.T) {
	bbox := computeBBox(nil)
	if bbox != nil {
		t.Errorf("expected nil for empty coords, got %v", bbox)
	}
}

func TestDisambiguateSlugs_DifferentVoivodeships(t *testing.T) {
	// Pass 1: same slug, different voivodeships → append voivodeship
	areas := []externalArea{
		{Slug: "olsztyn", Voivodeship: "WARMINSKO-MAZURSKIE", Terc: "2862011"},
		{Slug: "olsztyn", Voivodeship: "SLASKIE", Terc: "2404122"},
		{Slug: "unique", Voivodeship: "MAZOWIECKIE", Terc: "1234567"},
	}

	disambiguateSlugs(areas, nil)

	if areas[0].Slug != "olsztyn-warminsko-mazurskie" {
		t.Errorf("areas[0].Slug = %q, want olsztyn-warminsko-mazurskie", areas[0].Slug)
	}
	if areas[1].Slug != "olsztyn-slaskie" {
		t.Errorf("areas[1].Slug = %q, want olsztyn-slaskie", areas[1].Slug)
	}
	if areas[2].Slug != "unique" {
		t.Errorf("unique slug changed: %q", areas[2].Slug)
	}
}

func TestDisambiguateSlugs_SameVoivodeshipUniqueTypes(t *testing.T) {
	// Pass 1 + Pass 2: same slug, same voivodeship, unique TERC types
	areas := []externalArea{
		{Slug: "gubin", Voivodeship: "LUBUSKIE", Terc: "0802011"}, // 1 = miejska
		{Slug: "gubin", Voivodeship: "LUBUSKIE", Terc: "0802052"}, // 2 = wiejska
	}

	disambiguateSlugs(areas, nil)

	if areas[0].Slug != "gubin-lubuskie-miejska" {
		t.Errorf("areas[0].Slug = %q, want gubin-lubuskie-miejska", areas[0].Slug)
	}
	if areas[1].Slug != "gubin-lubuskie-wiejska" {
		t.Errorf("areas[1].Slug = %q, want gubin-lubuskie-wiejska", areas[1].Slug)
	}
}

func TestDisambiguateSlugs_SameVoivodeshipCountyFallback(t *testing.T) {
	// Pass 1 + Pass 2: same slug, same voivodeship, NON-unique TERC types → county fallback
	areas := []externalArea{
		{Slug: "czarna", Voivodeship: "PODKARPACKIE", Terc: "1810032"}, // all type 2
		{Slug: "czarna", Voivodeship: "PODKARPACKIE", Terc: "1801032"},
		{Slug: "czarna", Voivodeship: "PODKARPACKIE", Terc: "1803032"},
	}

	counties := []externalArea{
		{Slug: "lancucki", Terc: "1810"},
		{Slug: "bieszczadzki", Terc: "1801"},
		{Slug: "debicki", Terc: "1803"},
	}

	disambiguateSlugs(areas, counties)

	if areas[0].Slug != "czarna-podkarpackie-lancucki" {
		t.Errorf("areas[0].Slug = %q, want czarna-podkarpackie-lancucki", areas[0].Slug)
	}
	if areas[1].Slug != "czarna-podkarpackie-bieszczadzki" {
		t.Errorf("areas[1].Slug = %q, want czarna-podkarpackie-bieszczadzki", areas[1].Slug)
	}
	if areas[2].Slug != "czarna-podkarpackie-debicki" {
		t.Errorf("areas[2].Slug = %q, want czarna-podkarpackie-debicki", areas[2].Slug)
	}
}

func TestDisambiguateSlugs_MixedVoivodeshipAndType(t *testing.T) {
	// 4 entries: 2 voivodeships, 2 per voivodeship needing type disambiguation
	areas := []externalArea{
		{Slug: "test", Voivodeship: "AAA", Terc: "0101011"}, // 1 = miejska
		{Slug: "test", Voivodeship: "AAA", Terc: "0101022"}, // 2 = wiejska
		{Slug: "test", Voivodeship: "BBB", Terc: "0201013"}, // 3 = miejsko-wiejska
	}

	disambiguateSlugs(areas, nil)

	if areas[0].Slug != "test-aaa-miejska" {
		t.Errorf("areas[0].Slug = %q, want test-aaa-miejska", areas[0].Slug)
	}
	if areas[1].Slug != "test-aaa-wiejska" {
		t.Errorf("areas[1].Slug = %q, want test-aaa-wiejska", areas[1].Slug)
	}
	// BBB only has one entry after pass 1, so no pass 2 needed
	if areas[2].Slug != "test-bbb" {
		t.Errorf("areas[2].Slug = %q, want test-bbb", areas[2].Slug)
	}
}

func TestDisambiguateSlugs_NoCollisions(t *testing.T) {
	areas := []externalArea{
		{Slug: "a", Voivodeship: "X", Terc: "1111111"},
		{Slug: "b", Voivodeship: "Y", Terc: "2222222"},
	}

	disambiguateSlugs(areas, nil)

	if areas[0].Slug != "a" {
		t.Errorf("slug changed: %q", areas[0].Slug)
	}
	if areas[1].Slug != "b" {
		t.Errorf("slug changed: %q", areas[1].Slug)
	}
}

func TestCountySlugForTerc(t *testing.T) {
	counties := []externalArea{
		{Slug: "lancucki", Terc: "1810"},
		{Slug: "bieszczadzki", Terc: "1801"},
	}

	if got := countySlugForTerc("1810032", counties); got != "lancucki" {
		t.Errorf("got %q, want lancucki", got)
	}
	if got := countySlugForTerc("1801032", counties); got != "bieszczadzki" {
		t.Errorf("got %q, want bieszczadzki", got)
	}
	if got := countySlugForTerc("9999999", counties); got != "" {
		t.Errorf("expected empty for unknown TERC, got %q", got)
	}
}

func TestGenerateAreaConfigs_WritesFiles(t *testing.T) {
	extDir := t.TempDir()

	// Create minimal external YAML for each type
	townsYAML := `- slug: testville
  name: Testville
  terc: "1234567"
  voivodeship: TESTOWE
  polygon:
  - - 51.0
    - 19.0
  - - 51.1
    - 19.1
  - - 51.0
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
	result, err := GenerateAreaConfigs(extDir, outDir, true)
	if err != nil {
		t.Fatalf("GenerateAreaConfigs: %v", err)
	}

	if result.TotalAreas != 1 {
		t.Errorf("total = %d, want 1", result.TotalAreas)
	}
	if result.TypeCounts["towns"] != 1 {
		t.Errorf("towns = %d, want 1", result.TypeCounts["towns"])
	}

	// Verify file content
	data, err := os.ReadFile(filepath.Join(outDir, "areas", "towns.yml"))
	if err != nil {
		t.Fatalf("read output: %v", err)
	}

	var entries []areaConfigEntry
	if err := yaml.Unmarshal(data, &entries); err != nil {
		t.Fatalf("parse output: %v", err)
	}

	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}

	entry := entries[0]
	if entry.Slug != "testville" {
		t.Errorf("slug = %q", entry.Slug)
	}
	if entry.Code != "1234567" {
		t.Errorf("code = %q", entry.Code)
	}
	if entry.Voivodeship != "testowe" {
		t.Errorf("voivodeship = %q, want testowe (lowercased)", entry.Voivodeship)
	}
	if entry.BBox == nil {
		t.Fatal("bbox is nil")
	}
	// Polygon was [lat=51.0, lon=19.0], [lat=51.1, lon=19.1], [lat=51.0, lon=19.1]
	// After normalization to [lon, lat]: [19.0, 51.0], [19.1, 51.1], [19.1, 51.0]
	if entry.BBox.South != 51.0 {
		t.Errorf("south = %f, want 51.0", entry.BBox.South)
	}
	if entry.BBox.North != 51.1 {
		t.Errorf("north = %f, want 51.1", entry.BBox.North)
	}
	if entry.BBox.West != 19.0 {
		t.Errorf("west = %f, want 19.0", entry.BBox.West)
	}
	if entry.BBox.East != 19.1 {
		t.Errorf("east = %f, want 19.1", entry.BBox.East)
	}
}

func TestGenerateAreaConfigs_MesoRegionNoVoivodeship(t *testing.T) {
	extDir := t.TempDir()

	mesoYAML := `- slug: test_region
  name: Test Region
  kod: "315.11"
  polygon:
  - - 20.0
    - 51.0
  - - 20.1
    - 51.1
  - - 20.0
    - 51.1
`
	for _, at := range model.AllAreaTypes() {
		content := "[]"
		if at == model.AreaTypeMesoRegion {
			content = mesoYAML
		}
		if err := os.WriteFile(filepath.Join(extDir, at.EnglishPlural()+".yaml"), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	outDir := t.TempDir()
	_, err := GenerateAreaConfigs(extDir, outDir, true)
	if err != nil {
		t.Fatalf("GenerateAreaConfigs: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(outDir, "areas", "meso_regions.yml"))
	if err != nil {
		t.Fatalf("read output: %v", err)
	}

	var entries []areaConfigEntry
	if err := yaml.Unmarshal(data, &entries); err != nil {
		t.Fatalf("parse output: %v", err)
	}

	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}

	entry := entries[0]
	if entry.Code != "315.11" {
		t.Errorf("code = %q, want 315.11 (from kod)", entry.Code)
	}
	if entry.Voivodeship != "" {
		t.Errorf("voivodeship = %q, want empty for geographic region", entry.Voivodeship)
	}
}

func TestGenerateAreaConfigs_SkipsWhenExists(t *testing.T) {
	extDir := t.TempDir()
	for _, at := range model.AllAreaTypes() {
		if err := os.WriteFile(filepath.Join(extDir, at.EnglishPlural()+".yaml"), []byte("[]"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	outDir := t.TempDir()

	// First run: generates files
	_, err := GenerateAreaConfigs(extDir, outDir, false)
	if err != nil {
		t.Fatalf("first run: %v", err)
	}

	// Second run: skips
	result, err := GenerateAreaConfigs(extDir, outDir, false)
	if err != nil {
		t.Fatalf("second run: %v", err)
	}

	for _, at := range model.AllAreaTypes() {
		if result.TypeCounts[at.EnglishPlural()] != -1 {
			t.Errorf("%s not skipped: count=%d", at.EnglishPlural(), result.TypeCounts[at.EnglishPlural()])
		}
	}
}

// TestIntegration_AreaConfigsMatchCrystal compares Go-generated area configs
// against Crystal-generated ones for structural consistency.
func TestIntegration_AreaConfigsMatchCrystal(t *testing.T) {
	externalDir := filepath.Join("..", "..", "data", "external")
	crystalDir := filepath.Join("..", "..", "data", "config", "areas")

	if _, err := os.Stat(filepath.Join(externalDir, "towns.yaml")); err != nil {
		t.Skip("external data not available")
	}
	if _, err := os.Stat(filepath.Join(crystalDir, "towns.yml")); err != nil {
		t.Skip("Crystal area configs not available")
	}

	outDir := t.TempDir()
	result, err := GenerateAreaConfigs(externalDir, outDir, true)
	if err != nil {
		t.Fatalf("GenerateAreaConfigs: %v", err)
	}

	// Load Crystal configs for comparison
	for _, areaType := range model.AllAreaTypes() {
		typeName := areaType.EnglishPlural()

		crystalData, err := os.ReadFile(filepath.Join(crystalDir, typeName+".yml"))
		if err != nil {
			t.Errorf("read Crystal %s: %v", typeName, err)
			continue
		}

		var crystalEntries []areaConfigEntry
		if err := yaml.Unmarshal(crystalData, &crystalEntries); err != nil {
			t.Errorf("parse Crystal %s: %v", typeName, err)
			continue
		}

		goCount := result.TypeCounts[typeName]
		crystalCount := len(crystalEntries)

		if goCount != crystalCount {
			t.Errorf("%s: Go=%d Crystal=%d entries", typeName, goCount, crystalCount)
		} else {
			t.Logf("%s: %d entries match", typeName, goCount)
		}

		// Build Crystal slug set for comparison
		crystalSlugs := make(map[string]bool)
		for _, entry := range crystalEntries {
			crystalSlugs[entry.Slug] = true
		}

		// Read Go output and check slug matches
		goData, err := os.ReadFile(filepath.Join(outDir, "areas", typeName+".yml"))
		if err != nil {
			t.Errorf("read Go %s: %v", typeName, err)
			continue
		}
		var goEntries []areaConfigEntry
		if err := yaml.Unmarshal(goData, &goEntries); err != nil {
			t.Errorf("parse Go %s: %v", typeName, err)
			continue
		}

		missingInCrystal := 0
		for _, entry := range goEntries {
			if !crystalSlugs[entry.Slug] {
				if missingInCrystal < 5 {
					t.Logf("  %s: Go slug %q not in Crystal", typeName, entry.Slug)
				}
				missingInCrystal++
			}
		}
		if missingInCrystal > 0 {
			t.Errorf("%s: %d Go slugs not found in Crystal output", typeName, missingInCrystal)
		}
	}
}
