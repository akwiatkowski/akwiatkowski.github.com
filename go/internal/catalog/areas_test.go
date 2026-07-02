package catalog

import (
	"path/filepath"
	"testing"

	"odkrywajac/internal/model"
)

func TestLoadAreas(t *testing.T) {
	cfgDir := configDir(t)
	areas, err := LoadAreas(filepath.Join(cfgDir, "areas"))
	if err != nil {
		t.Fatal(err)
	}
	if len(areas) < 100 {
		t.Errorf("expected at least 100 areas, got %d", len(areas))
	}

	// Count by type
	counts := make(map[model.AreaType]int)
	for _, a := range areas {
		counts[a.Type]++
	}

	if counts[model.AreaTypeTown] < 2000 {
		t.Errorf("expected 2000+ towns, got %d", counts[model.AreaTypeTown])
	}
	if counts[model.AreaTypeVoivodeship] != 16 {
		t.Errorf("expected 16 voivodeships, got %d", counts[model.AreaTypeVoivodeship])
	}

	// Check sorting: all towns should come before counties
	var sawCounty bool
	for _, a := range areas {
		if a.Type == model.AreaTypeCounty {
			sawCounty = true
		}
		if a.Type == model.AreaTypeTown && sawCounty {
			t.Error("areas not sorted by type: town found after county")
			break
		}
	}

	// Check that areas have slugs and bbox
	for _, a := range areas {
		if a.Slug == "" {
			t.Errorf("area with empty slug: %v", a)
		}
		if a.BBox == nil {
			t.Logf("area %s:%s has no bbox", a.Type, a.Slug)
		}
	}
}

func TestLoadAreasSetsType(t *testing.T) {
	cfgDir := configDir(t)
	areas, err := LoadAreas(filepath.Join(cfgDir, "areas"))
	if err != nil {
		t.Fatal(err)
	}

	// Every area should have its type set
	for _, a := range areas {
		if a.Type.String() == "" {
			t.Errorf("area %s has no type set", a.Slug)
		}
	}

	// Check a known voivodeship
	for _, a := range areas {
		if a.Type == model.AreaTypeVoivodeship && a.Slug == "wielkopolskie" {
			if a.Name == "" {
				t.Error("wielkopolskie has no name")
			}
			return
		}
	}
	t.Error("voivodeship wielkopolskie not found")
}
