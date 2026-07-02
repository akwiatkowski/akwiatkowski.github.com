package spatial

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteRouteCoverage_RoundTrip(t *testing.T) {
	tmpDir := t.TempDir()
	cacheDir := filepath.Join(tmpDir, "areas_for_post")

	result := &RouteResult{
		Segments: []SegmentResult{
			{
				Type:           "bicycle",
				TotalDistanceM: 50000.0,
				PointsCount:    120,
				Towns: []AreaDistance{
					{Slug: "rynsk", Name: "Ryńsk", Code: "0417052", DistanceM: 20000.0, DistanceKm: 20.0, DistancePercent: 40.0},
					{Slug: "gruta", Name: "Gruta", Code: "0406022", DistanceM: 15000.0, DistanceKm: 15.0, DistancePercent: 30.0},
				},
				Counties: []AreaDistance{
					{Slug: "wabrzeski", Name: "wąbrzeski", Code: "0417", DistanceM: 50000.0, DistanceKm: 50.0, DistancePercent: 100.0},
				},
				TouchedTowns: []AreaRef{
					{Slug: "rynsk", Name: "Ryńsk", Code: "0417052"},
					{Slug: "gruta", Name: "Gruta", Code: "0406022"},
				},
			},
		},
	}

	err := WriteRouteCoverage(cacheDir, "2021-07-24-test-post", result)
	if err != nil {
		t.Fatalf("WriteRouteCoverage: %v", err)
	}

	// Verify file exists
	path := filepath.Join(cacheDir, "2021-07-24-test-post.yml")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read cache file: %v", err)
	}

	content := string(data)

	// Verify YAML document separator
	if !strings.HasPrefix(content, "---\n") {
		t.Error("expected YAML document separator prefix")
	}

	// Verify key fields are present
	for _, expected := range []string{
		"type: bicycle",
		"slug: rynsk",
		"slug: gruta",
		"slug: wabrzeski",
		"distance_meters:",
		"distance_km:",
		"distance_percent:",
		"touched_towns:",
	} {
		if !strings.Contains(content, expected) {
			t.Errorf("expected %q in output, not found", expected)
		}
	}
}

func TestWritePhotosInArea_RoundTrip(t *testing.T) {
	tmpDir := t.TempDir()
	cacheDir := filepath.Join(tmpDir, "photos_in_area")

	assignments := map[AreaKey][]PhotoRef{
		{TypePlural: "towns", Slug: "radzyn_chelminski"}: {
			{Filename: "2021_07_24__15_49_DSC03287.jpg", PostSlug: "2021-07-24-w-trakcie-zniw"},
			{Filename: "2021_07_24__16_00_DSC03291.jpg", PostSlug: "2021-07-24-w-trakcie-zniw"},
		},
	}

	err := WritePhotosInArea(cacheDir, assignments)
	if err != nil {
		t.Fatalf("WritePhotosInArea: %v", err)
	}

	// Verify file exists at correct path
	path := filepath.Join(cacheDir, "towns", "radzyn_chelminski.yml")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read cache file: %v", err)
	}

	content := string(data)

	// Verify Crystal-compatible format
	if !strings.HasPrefix(content, "---\n") {
		t.Error("expected YAML document separator prefix")
	}
	if !strings.Contains(content, "filename: 2021_07_24__15_49_DSC03287.jpg") {
		t.Error("expected filename in output")
	}
	if !strings.Contains(content, "post_slug: 2021-07-24-w-trakcie-zniw") {
		t.Error("expected post_slug in output")
	}
}

func TestIsRouteCoverageStale_MissingFile(t *testing.T) {
	tmpDir := t.TempDir()
	if !IsRouteCoverageStale(tmpDir, "nonexistent", nil) {
		t.Error("expected stale for missing file")
	}
}

func TestIsRouteCoverageStale_FreshFile(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a cache file
	cachePath := filepath.Join(tmpDir, "test-post.yml")
	if err := os.WriteFile(cachePath, []byte("test"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	// No route paths to compare against → not stale
	if IsRouteCoverageStale(tmpDir, "test-post", nil) {
		t.Error("expected fresh when no route paths")
	}
}
