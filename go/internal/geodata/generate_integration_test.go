package geodata

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestIntegration_LoadRealTowns loads data/external/towns.yaml and verifies
// a known town (jablonowo_pomorskie) is present with valid polygon data.
// This test is skipped if the external data directory doesn't exist.
func TestIntegration_LoadRealTowns(t *testing.T) {
	externalDir := filepath.Join("..", "..", "data", "external")
	if _, err := os.Stat(filepath.Join(externalDir, "towns.yaml")); err != nil {
		t.Skip("external data not available, skipping integration test")
	}

	external, err := LoadExternalAreas(externalDir)
	if err != nil {
		t.Fatalf("LoadExternalAreas: %v", err)
	}

	towns := external["towns"]
	if len(towns) == 0 {
		t.Fatal("no towns loaded")
	}

	// Find jablonowo_pomorskie
	idx := BuildSlugIndex(towns)
	town, ok := idx["jablonowo_pomorskie"]
	if !ok {
		t.Fatal("jablonowo_pomorskie not found in external data")
	}

	if town.Name == "" {
		t.Error("town name is empty")
	}
	if len(town.Polygon) < 3 {
		t.Errorf("polygon has %d points, expected at least 3", len(town.Polygon))
	}

	// Verify polygon points have [lat, lon] format (lat should be ~53, lon ~18-19)
	firstPoint := town.Polygon[0]
	if firstPoint[0] < 50 || firstPoint[0] > 55 {
		t.Errorf("first point lat=%f, expected ~53 (Poland)", firstPoint[0])
	}
	if firstPoint[1] < 17 || firstPoint[1] > 21 {
		t.Errorf("first point lon=%f, expected ~18-19 (Poland)", firstPoint[1])
	}
}

// TestIntegration_GenerateMatchesCrystal generates a polygon for a known town
// and verifies the output structure matches the Crystal-generated format.
func TestIntegration_GenerateMatchesCrystal(t *testing.T) {
	externalDir := filepath.Join("..", "..", "data", "external")
	crystalDir := filepath.Join("..", "..", "data", "config", "polygons", "towns")

	crystalPath := filepath.Join(crystalDir, "jablonowo_pomorskie.json")
	if _, err := os.Stat(crystalPath); err != nil {
		t.Skip("Crystal polygon output not available, skipping integration test")
	}
	if _, err := os.Stat(filepath.Join(externalDir, "towns.yaml")); err != nil {
		t.Skip("external data not available, skipping integration test")
	}

	// Load external data
	external, err := LoadExternalAreas(externalDir)
	if err != nil {
		t.Fatalf("LoadExternalAreas: %v", err)
	}

	idx := BuildSlugIndex(external["towns"])
	town, ok := idx["jablonowo_pomorskie"]
	if !ok {
		t.Fatal("jablonowo_pomorskie not found")
	}

	// Generate with same tolerance as Crystal (0.001)
	goData, err := buildGeoJSON(town, "town", DefaultTolerance)
	if err != nil {
		t.Fatalf("buildGeoJSON: %v", err)
	}

	// Load Crystal output
	crystalData, err := os.ReadFile(crystalPath)
	if err != nil {
		t.Fatalf("read Crystal output: %v", err)
	}

	// Parse both
	var goFeature, crystalFeature geoJSONFeature
	if err := json.Unmarshal(goData, &goFeature); err != nil {
		t.Fatalf("parse Go output: %v", err)
	}
	if err := json.Unmarshal(crystalData, &crystalFeature); err != nil {
		t.Fatalf("parse Crystal output: %v", err)
	}

	// Compare structure (not exact coordinates, since floating point may differ slightly)
	if goFeature.Type != crystalFeature.Type {
		t.Errorf("type: go=%q crystal=%q", goFeature.Type, crystalFeature.Type)
	}
	if goFeature.Properties.Slug != crystalFeature.Properties.Slug {
		t.Errorf("slug: go=%q crystal=%q", goFeature.Properties.Slug, crystalFeature.Properties.Slug)
	}
	if goFeature.Properties.Type != crystalFeature.Properties.Type {
		t.Errorf("properties.type: go=%q crystal=%q", goFeature.Properties.Type, crystalFeature.Properties.Type)
	}
	if goFeature.Geometry.Type != crystalFeature.Geometry.Type {
		t.Errorf("geometry type: go=%q crystal=%q", goFeature.Geometry.Type, crystalFeature.Geometry.Type)
	}

	// Validate Go output structure
	if err := ValidateGeoJSONOutput(goData); err != nil {
		t.Errorf("Go output validation failed: %v", err)
	}

	// Compare point counts — should be similar (same algorithm, same tolerance)
	goPoints := len(goFeature.Geometry.Coordinates[0])
	crystalPoints := len(crystalFeature.Geometry.Coordinates[0])
	t.Logf("Point counts: go=%d crystal=%d (original=%d)",
		goPoints, crystalPoints, goFeature.Properties.OriginalPoints)

	// Allow small differences due to floating point
	diff := goPoints - crystalPoints
	if diff < 0 {
		diff = -diff
	}
	if diff > 2 {
		t.Errorf("point count difference too large: go=%d crystal=%d", goPoints, crystalPoints)
	}
}

// TestIntegration_AllAreaTypes verifies all 5 external YAML files can be loaded.
func TestIntegration_AllAreaTypes(t *testing.T) {
	externalDir := filepath.Join("..", "..", "data", "external")
	if _, err := os.Stat(filepath.Join(externalDir, "towns.yaml")); err != nil {
		t.Skip("external data not available")
	}

	external, err := LoadExternalAreas(externalDir)
	if err != nil {
		t.Fatalf("LoadExternalAreas: %v", err)
	}

	expected := map[string]int{
		"towns":         2000, // at least this many
		"counties":      300,
		"voivodeships":  16,
		"meso_regions":  200,
		"macro_regions": 40,
	}

	for typeName, minCount := range expected {
		areas, ok := external[typeName]
		if !ok {
			t.Errorf("missing type %s", typeName)
			continue
		}
		if len(areas) < minCount {
			t.Errorf("%s: got %d areas, expected at least %d", typeName, len(areas), minCount)
		}
		t.Logf("%s: %d areas loaded", typeName, len(areas))
	}
}
