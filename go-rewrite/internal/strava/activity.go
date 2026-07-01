// Package strava loads Strava activity data from JSON exports.
package strava

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Activity represents a Strava activity export.
type Activity struct {
	ID                 int64     `json:"id"`
	Name               string    `json:"name"`
	Type               string    `json:"type"`       // Ride, Hike, Walk, etc.
	SportType          string    `json:"sport_type"` // GravelRide, MountainBikeRide, etc.
	Distance           float64   `json:"distance"`   // meters
	MovingTime         int       `json:"moving_time"` // seconds
	TotalElevationGain float64   `json:"total_elevation_gain"`
	StartDate          time.Time `json:"start_date"`
	StartDateLocal     time.Time `json:"start_date_local"`
	AverageSpeed       float64   `json:"average_speed"`
	MaxSpeed           float64   `json:"max_speed"`
	StartLatLng        []float64 `json:"start_latlng"` // [lat, lon]
	EndLatLng          []float64 `json:"end_latlng"`   // [lat, lon]
	Map                struct {
		SummaryPolyline string `json:"summary_polyline"`
	} `json:"map"`
}

// IsBike returns true if this is a bicycle activity.
func (a *Activity) IsBike() bool {
	t := strings.ToLower(a.Type)
	st := strings.ToLower(a.SportType)
	return t == "ride" || t == "ebikeride" ||
		st == "gravelride" || st == "mountainbikeride" ||
		st == "roadride" || st == "cyclocross"
}

// IsHike returns true if this is a walking/hiking activity.
func (a *Activity) IsHike() bool {
	t := strings.ToLower(a.Type)
	return t == "hike" || t == "walk"
}

// DistanceKm returns the distance in kilometers.
func (a *Activity) DistanceKm() float64 {
	return a.Distance / 1000.0
}

// DurationHours returns the moving time in hours.
func (a *Activity) DurationHours() float64 {
	return float64(a.MovingTime) / 3600.0
}

// StravaURL returns the full Strava activity URL.
func (a *Activity) StravaURL() string {
	return fmt.Sprintf("https://www.strava.com/activities/%d", a.ID)
}

// IsLongEnough returns true if the activity meets the minimum distance threshold.
// Bikes: >= 25km, Hikes: >= 2km, Others: always true.
func (a *Activity) IsLongEnough() bool {
	if a.IsBike() {
		return a.DistanceKm() >= 25.0
	}
	if a.IsHike() {
		return a.DistanceKm() >= 2.0
	}
	return true
}

// LoadActivities reads all Strava activity JSON files from the given directory.
func LoadActivities(dir string) ([]*Activity, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read activities directory: %w", err)
	}

	var activities []*Activity
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		path := filepath.Join(dir, entry.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue // skip unreadable files
		}

		var activity Activity
		if err := json.Unmarshal(data, &activity); err != nil {
			continue // skip unparseable files
		}

		activities = append(activities, &activity)
	}

	return activities, nil
}

// ExtractActivityID parses a Strava URL or ID string and returns the numeric ID.
// Handles: "https://www.strava.com/activities/12345" or "12345".
func ExtractActivityID(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	if s == "" || strings.HasPrefix(s, "#") {
		return 0, false
	}

	// Extract from URL
	if strings.Contains(s, "/activities/") {
		parts := strings.Split(s, "/activities/")
		if len(parts) == 2 {
			s = strings.TrimSpace(parts[1])
		}
	}

	id, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0, false
	}
	return id, true
}
