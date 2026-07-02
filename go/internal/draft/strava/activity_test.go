package strava

import (
	"testing"
)

func TestActivityIsBike(t *testing.T) {
	tests := []struct {
		typ       string
		sportType string
		want      bool
	}{
		{"Ride", "", true},
		{"EBikeRide", "", true},
		{"Hike", "", false},
		{"Walk", "", false},
		{"", "GravelRide", true},
		{"", "MountainBikeRide", true},
		{"", "RoadRide", true},
		{"Ride", "GravelRide", true},
	}

	for _, tt := range tests {
		a := &Activity{Type: tt.typ, SportType: tt.sportType}
		if got := a.IsBike(); got != tt.want {
			t.Errorf("IsBike(type=%q, sport_type=%q) = %v, want %v",
				tt.typ, tt.sportType, got, tt.want)
		}
	}
}

func TestActivityIsHike(t *testing.T) {
	tests := []struct {
		typ  string
		want bool
	}{
		{"Hike", true},
		{"Walk", true},
		{"Ride", false},
		{"EBikeRide", false},
		{"", false},
	}

	for _, tt := range tests {
		a := &Activity{Type: tt.typ}
		if got := a.IsHike(); got != tt.want {
			t.Errorf("IsHike(type=%q) = %v, want %v", tt.typ, got, tt.want)
		}
	}
}

func TestActivityIsLongEnough(t *testing.T) {
	tests := []struct {
		typ      string
		distance float64
		want     bool
	}{
		{"Ride", 25000, true},  // 25km bike = exactly threshold
		{"Ride", 24000, false}, // 24km bike = below
		{"Ride", 30000, true},  // 30km bike = above
		{"EBikeRide", 25000, true},
		{"Hike", 2000, true},     // 2km hike = exactly threshold
		{"Hike", 1500, false},    // 1.5km hike = below
		{"Walk", 3000, true},     // 3km walk = above
		{"Kayaking", 1000, true}, // Other types always pass
	}

	for _, tt := range tests {
		a := &Activity{Type: tt.typ, Distance: tt.distance}
		if got := a.IsLongEnough(); got != tt.want {
			t.Errorf("IsLongEnough(type=%q, distance=%.0f) = %v, want %v",
				tt.typ, tt.distance, got, tt.want)
		}
	}
}

func TestExtractActivityID(t *testing.T) {
	tests := []struct {
		input string
		want  int64
		ok    bool
	}{
		{"https://www.strava.com/activities/12345", 12345, true},
		{"12345", 12345, true},
		{"  12345  ", 12345, true},
		{"# comment", 0, false},
		{"", 0, false},
		{"https://www.strava.com/activities/abc", 0, false},
	}

	for _, tt := range tests {
		got, ok := ExtractActivityID(tt.input)
		if ok != tt.ok {
			t.Errorf("ExtractActivityID(%q) ok = %v, want %v", tt.input, ok, tt.ok)
			continue
		}
		if ok && got != tt.want {
			t.Errorf("ExtractActivityID(%q) = %d, want %d", tt.input, got, tt.want)
		}
	}
}

func TestActivityStravaURL(t *testing.T) {
	a := &Activity{ID: 12345}
	want := "https://www.strava.com/activities/12345"
	if got := a.StravaURL(); got != want {
		t.Errorf("StravaURL() = %q, want %q", got, want)
	}
}

func TestActivityDistanceKm(t *testing.T) {
	a := &Activity{Distance: 5000}
	if got := a.DistanceKm(); got != 5.0 {
		t.Errorf("DistanceKm() = %f, want 5.0", got)
	}
}

func TestActivityDurationHours(t *testing.T) {
	a := &Activity{MovingTime: 3600}
	if got := a.DurationHours(); got != 1.0 {
		t.Errorf("DurationHours() = %f, want 1.0", got)
	}
}

func TestLoadActivities(t *testing.T) {
	// Test with the actual Strava data directory
	baseDir := "/Users/olek/projects/llm/input/cycling/strava/activities"
	activities, err := LoadActivities(baseDir)
	if err != nil {
		t.Fatalf("LoadActivities failed: %v", err)
	}
	if len(activities) == 0 {
		t.Error("expected some activities, got 0")
	}

	// Check that all activities have valid IDs
	for _, a := range activities {
		if a.ID == 0 {
			t.Error("activity with ID=0 found")
		}
		if a.StartDate.IsZero() {
			t.Errorf("activity %d has zero start date", a.ID)
		}
	}
}

func TestLoadActivitiesMissingDir(t *testing.T) {
	_, err := LoadActivities("/nonexistent/path")
	if err == nil {
		t.Error("expected error for missing directory")
	}
}
