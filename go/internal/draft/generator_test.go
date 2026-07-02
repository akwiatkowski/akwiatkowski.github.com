package draft

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/draft/gpx"
	"odkrywajac/internal/draft/weather"
)

func TestGenerate_CreatesDraft(t *testing.T) {
	tmpDir := t.TempDir()
	gen := &Generator{PostsDir: tmpDir}

	stats := &gpx.RideStats{
		StartTime:     time.Date(2026, 6, 3, 9, 0, 0, 0, time.UTC),
		EndTime:       time.Date(2026, 6, 3, 11, 0, 0, 0, time.UTC),
		Duration:      2 * time.Hour,
		DistanceKm:    45.5,
		ElevationGain: 333,
		ElevationLoss: 300,
		MinElevation:  80,
		MaxElevation:  120,
		ActivityType:  "e-bike",
	}

	opts := Options{
		Title:    "Test Ride",
		Author:   "Test Author",
		Category: "trip",
		Tags:     []string{"bicycle", "todo"},
	}

	path, err := gen.Generate(stats, opts)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}

	if !strings.HasSuffix(path, "2026-06-03-test-ride.md") {
		t.Errorf("path = %q, want suffix 2026-06-03-test-ride.md", path)
	}

	content, err := os.ReadFile(filepath.Join(tmpDir, "2026-06-03-test-ride.md"))
	if err != nil {
		t.Fatalf("read generated file: %v", err)
	}

	s := string(content)
	if !strings.Contains(s, "title:                  \"Test Ride\"") {
		t.Error("missing title in draft")
	}
	if !strings.Contains(s, "author:                 \"Test Author\"") {
		t.Error("missing author in draft")
	}
	if !strings.Contains(s, "distance:               46") {
		t.Error("missing distance in draft")
	}
	if !strings.Contains(s, "e-bike") {
		t.Error("missing activity type in draft")
	}
}

func TestGenerate_WithWeather(t *testing.T) {
	tmpDir := t.TempDir()
	gen := &Generator{PostsDir: tmpDir}

	stats := &gpx.RideStats{
		StartTime:    time.Date(2026, 6, 3, 9, 0, 0, 0, time.UTC),
		Duration:     1 * time.Hour,
		DistanceKm:   20,
		ActivityType: "bicycle",
	}

	w := &weather.Data{
		Temperature: 22.5,
		CloudCover:  30,
		WindSpeed:   10,
	}

	opts := Options{
		Title:   "Sunny Ride",
		Author:  "Test",
		Weather: w,
		DryRun:  false,
	}

	_, err := gen.Generate(stats, opts)
	if err != nil {
		t.Fatalf("Generate failed: %v", err)
	}

	content, _ := os.ReadFile(filepath.Join(tmpDir, "2026-06-03-sunny-ride.md"))
	s := string(content)
	if !strings.Contains(s, "22.5°C") {
		t.Error("missing weather data in draft")
	}
}

func TestSlugify(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Hello World", "hello-world"},
		{"Rowerem do Kiszkowa", "rowerem-do-kiszkowa"},
		{"Łąki i pola", "laki-i-pola"},
		{"", ""},
		{"Test-123", "test-123"},
	}

	for _, tt := range tests {
		got := slugify(tt.input)
		if got != tt.want {
			t.Errorf("slugify(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
