package exif

import (
	"os"
	"testing"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

func TestCacheRoundTrip(t *testing.T) {
	tmpDir := t.TempDir()
	cache := NewCache(tmpDir)

	// Create a test EXIF entry
	lat := 52.4
	lon := 16.9
	iso := 400
	testData := &model.ExifData{
		Lat:    &lat,
		Lon:    &lon,
		ISO:    &iso,
		Camera: "E-M1MarkII",
		Lens:   "M.12-100mm F4.0",
	}

	entry := cacheEntryFromExif("test.jpg", "test-post", testData)
	entries := []cacheEntry{entry}

	// Write cache file
	data, err := yaml.Marshal(entries)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(cache.cacheDir, 0o755); err != nil {
		t.Fatal(err)
	}
	header := []byte("---\n")
	if err := os.WriteFile(cache.cachePath("test-post"), append(header, data...), 0o644); err != nil {
		t.Fatal(err)
	}

	// Read back
	loaded, err := cache.Load("test-post")
	if err != nil {
		t.Fatal(err)
	}
	if len(loaded) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(loaded))
	}

	d := loaded[0]
	if d.Lat == nil || *d.Lat != 52.4 {
		t.Errorf("Lat = %v", d.Lat)
	}
	if d.Lon == nil || *d.Lon != 16.9 {
		t.Errorf("Lon = %v", d.Lon)
	}
	if d.Camera != "E-M1MarkII" {
		t.Errorf("Camera = %q", d.Camera)
	}
	if d.Lens != "M.12-100mm F4.0" {
		t.Errorf("Lens = %q", d.Lens)
	}
}

func TestCacheIsStale(t *testing.T) {
	tmpDir := t.TempDir()
	cache := NewCache(tmpDir)

	// No cache file → stale
	if !cache.IsStale("nonexistent", nil) {
		t.Error("missing cache should be stale")
	}
}

func TestCacheIsStaleWithFile(t *testing.T) {
	tmpDir := t.TempDir()
	cache := NewCache(tmpDir)

	// Create a cache file
	if err := os.MkdirAll(cache.cacheDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(cache.cachePath("test"), []byte("---\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// No source images → not stale
	if cache.IsStale("test", nil) {
		t.Error("cache with no source images should not be stale")
	}
}
