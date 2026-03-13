package loader

import (
	"os"
	"path/filepath"
	"testing"
)

// configDir returns the path to the real config directory.
// Tests use actual project config files for integration testing.
func configDir(t *testing.T) string {
	t.Helper()
	// Walk up from go-rewrite/internal/loader/ to project root
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// Find project root by looking for data/config/
	for {
		if _, err := os.Stat(filepath.Join(dir, "data", "config")); err == nil {
			return filepath.Join(dir, "data", "config")
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find data/config/ directory")
		}
		dir = parent
	}
}

func TestLoadSiteConfig(t *testing.T) {
	cfgDir := configDir(t)
	cfg, err := LoadSiteConfig(filepath.Join(cfgDir, "config.yml"))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Title != "OdkrywajacPolske.pl" {
		t.Errorf("Title = %q", cfg.Title)
	}
	if cfg.Author != "Aleksander Kwiatkowski" {
		t.Errorf("Author = %q", cfg.Author)
	}
	if cfg.URL == "" {
		t.Error("URL is empty")
	}
}

func TestLoadTags(t *testing.T) {
	cfgDir := configDir(t)
	tags, err := LoadTags(filepath.Join(cfgDir, "tags.yml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(tags) < 20 {
		t.Errorf("expected at least 20 tags, got %d", len(tags))
	}

	// Check a known tag
	var found bool
	for _, tag := range tags {
		if tag.Slug == "bicycle" {
			found = true
			if tag.SlugPl != "rowerem" {
				t.Errorf("bicycle.slug_pl = %q, want rowerem", tag.SlugPl)
			}
			if !tag.IsNav {
				t.Error("bicycle should be is_nav")
			}
		}
	}
	if !found {
		t.Error("bicycle tag not found")
	}
}

func TestLoadPhotoTags(t *testing.T) {
	cfgDir := configDir(t)
	tags, err := LoadPhotoTags(filepath.Join(cfgDir, "photo_tags.yml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(tags) < 10 {
		t.Errorf("expected at least 10 photo tags, got %d", len(tags))
	}

	// Check points on a known tag
	for _, tag := range tags {
		if tag.Slug == "best" {
			if tag.Points != 100 {
				t.Errorf("best.points = %d, want 100", tag.Points)
			}
		}
	}
}

func TestLoadRouteColors(t *testing.T) {
	cfgDir := configDir(t)
	colors, err := LoadRouteColors(filepath.Join(cfgDir, "route_colors.yml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) < 5 {
		t.Errorf("expected at least 5 route colors, got %d", len(colors))
	}
	hike, ok := colors["hike"]
	if !ok {
		t.Fatal("hike color not found")
	}
	if hike.Weight != 3 {
		t.Errorf("hike.weight = %d, want 3", hike.Weight)
	}
}

func TestLoadTrainStations(t *testing.T) {
	cfgDir := configDir(t)
	stations, err := LoadTrainStations(filepath.Join(cfgDir, "train_stations.yml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(stations) < 10 {
		t.Errorf("expected at least 10 stations, got %d", len(stations))
	}

	// Check Poznań station
	for _, s := range stations {
		if s.Name == "Poznań" {
			if s.PoznanTimeDistance() < 0.01 {
				t.Errorf("Poznań distance to itself should be ~0.05, got %v", s.PoznanTimeDistance())
			}
		}
	}
}

func TestLoadAllConfigs(t *testing.T) {
	cfgDir := configDir(t)
	cfg, tags, photoTags, colors, stations, err := LoadAllConfigs(cfgDir)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Title == "" {
		t.Error("config title is empty")
	}
	if len(tags) == 0 {
		t.Error("no tags loaded")
	}
	if len(photoTags) == 0 {
		t.Error("no photo tags loaded")
	}
	if len(colors) == 0 {
		t.Error("no route colors loaded")
	}
	if len(stations) == 0 {
		t.Error("no stations loaded")
	}
}
