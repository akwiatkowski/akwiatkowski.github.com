package gpx

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParseFile_ValidGPX(t *testing.T) {
	// Create a minimal GPX file for testing
	gpxContent := `<?xml version="1.0" encoding="UTF-8"?>
<gpx creator="Test" version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
 <metadata>
  <time>2026-06-03T09:00:00Z</time>
 </metadata>
 <trk>
  <name>Test Ride</name>
  <type>ebikeride</type>
  <trkseg>
   <trkpt lat="52.9000000" lon="18.1500000">
    <ele>100.0</ele>
    <time>2026-06-03T09:00:00Z</time>
   </trkpt>
   <trkpt lat="52.9001000" lon="18.1501000">
    <ele>105.0</ele>
    <time>2026-06-03T09:01:00Z</time>
   </trkpt>
   <trkpt lat="52.9002000" lon="18.1502000">
    <ele>102.0</ele>
    <time>2026-06-03T09:02:00Z</time>
   </trkpt>
  </trkseg>
 </trk>
</gpx>`

	tmpDir := t.TempDir()
	gpxPath := filepath.Join(tmpDir, "test.gpx")
	if err := os.WriteFile(gpxPath, []byte(gpxContent), 0644); err != nil {
		t.Fatalf("write test GPX: %v", err)
	}

	stats, err := ParseFile(gpxPath)
	if err != nil {
		t.Fatalf("ParseFile failed: %v", err)
	}

	if stats.ActivityType != "e-bike" {
		t.Errorf("ActivityType = %q, want e-bike", stats.ActivityType)
	}

	if stats.StartTime != time.Date(2026, 6, 3, 9, 0, 0, 0, time.UTC) {
		t.Errorf("StartTime = %v, want 2026-06-03 09:00:00 UTC", stats.StartTime)
	}

	if stats.Duration != 2*time.Minute {
		t.Errorf("Duration = %v, want 2m", stats.Duration)
	}

	if stats.DistanceKm <= 0 {
		t.Errorf("DistanceKm = %f, want > 0", stats.DistanceKm)
	}

	if stats.ElevationGain != 5.0 {
		t.Errorf("ElevationGain = %f, want 5.0", stats.ElevationGain)
	}

	if stats.ElevationLoss != 3.0 {
		t.Errorf("ElevationLoss = %f, want 3.0", stats.ElevationLoss)
	}

	if stats.MinElevation != 100.0 {
		t.Errorf("MinElevation = %f, want 100.0", stats.MinElevation)
	}

	if stats.MaxElevation != 105.0 {
		t.Errorf("MaxElevation = %f, want 105.0", stats.MaxElevation)
	}

	if len(stats.Points) != 3 {
		t.Errorf("Points = %d, want 3", len(stats.Points))
	}
}

func TestParseFile_MissingFile(t *testing.T) {
	_, err := ParseFile("/nonexistent/path/file.gpx")
	if err == nil {
		t.Error("expected error for missing file, got nil")
	}
}

func TestParseFile_EmptyTrack(t *testing.T) {
	gpxContent := `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
 <trk>
  <name>Empty</name>
  <trkseg>
  </trkseg>
 </trk>
</gpx>`

	tmpDir := t.TempDir()
	gpxPath := filepath.Join(tmpDir, "empty.gpx")
	if err := os.WriteFile(gpxPath, []byte(gpxContent), 0644); err != nil {
		t.Fatalf("write test GPX: %v", err)
	}

	_, err := ParseFile(gpxPath)
	if err == nil {
		t.Error("expected error for empty track, got nil")
	}
}

func TestHaversine(t *testing.T) {
	// Distance between two points ~1km apart
	dist := haversine(52.900000, 18.150000, 52.900100, 18.150100)
	if dist <= 0 {
		t.Errorf("haversine = %f, want > 0", dist)
	}
	// Should be roughly 12-15 meters
	if dist > 0.02 {
		t.Errorf("haversine = %f, want < 0.02 km", dist)
	}
}
