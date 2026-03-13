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

func TestLoadMapForPostUsesPrimaryCache(t *testing.T) {
	cacheDir := t.TempDir()
	imageDir := t.TempDir()
	cache := NewCache(cacheDir)

	// Write a cache entry
	writeCacheFile(t, cacheDir, "test-post", []cacheEntry{
		{ImageFilename: "photo.jpg", PostSlug: "test-post", Lat: floatPtr(52.0), Lon: floatPtr(17.0)},
	})

	result, err := cache.LoadMapForPost("test-post", imageDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(result) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(result))
	}
	if result["photo.jpg"] == nil || *result["photo.jpg"].Lat != 52.0 {
		t.Error("expected photo.jpg with lat=52.0")
	}
}

func TestLoadMapForPostEmptyImageDir(t *testing.T) {
	cacheDir := t.TempDir()
	imageDir := t.TempDir() // empty directory
	cache := NewCache(cacheDir)

	// No cache file, no images → should return empty map
	result, err := cache.LoadMapForPost("nonexistent", imageDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(result) != 0 {
		t.Errorf("expected empty map, got %d entries", len(result))
	}
}

func TestListImagePaths(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"a.jpg", "b.JPG", "c.png", "d.txt", "e.jpeg"} {
		if err := os.WriteFile(dir+"/"+name, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	paths := ListImagePaths(dir)
	if len(paths) != 4 {
		t.Fatalf("expected 4 image paths, got %d: %v", len(paths), paths)
	}

	// Should not contain d.txt
	for _, p := range paths {
		if p == dir+"/d.txt" {
			t.Error("d.txt should not be listed as an image")
		}
	}
}

func TestListImagePathsNonexistentDir(t *testing.T) {
	paths := ListImagePaths("/nonexistent/path")
	if paths != nil {
		t.Errorf("expected nil for nonexistent dir, got %v", paths)
	}
}

// --- helpers ---

func writeCacheFile(t *testing.T, dir, slug string, entries []cacheEntry) {
	t.Helper()
	data, err := yaml.Marshal(entries)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(dir+"/"+slug+".yml", append([]byte("---\n"), data...), 0o644); err != nil {
		t.Fatal(err)
	}
}

func floatPtr(f float64) *float64 { return &f }
