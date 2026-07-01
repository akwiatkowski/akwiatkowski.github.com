// Package gpx parses GPX files and computes ride statistics.
package gpx

import (
	"encoding/xml"
	"fmt"
	"math"
	"os"
	"time"
)

// TrackPoint represents a single GPS point from a GPX file.
type TrackPoint struct {
	Lat       float64
	Lon       float64
	Elevation float64
	Time      time.Time
}

// RideStats holds computed statistics from a GPX track.
type RideStats struct {
	StartTime     time.Time
	EndTime       time.Time
	Duration      time.Duration
	DistanceKm    float64
	ElevationGain float64
	ElevationLoss float64
	MinElevation  float64
	MaxElevation  float64
	StartPoint    TrackPoint
	EndPoint      TrackPoint
	Points        []TrackPoint
	ActivityType  string // bicycle, e-bike, hike, etc.
}

// gpxXML mirrors the structure of a Strava-exported GPX file.
type gpxXML struct {
	XMLName  xml.Name   `xml:"gpx"`
	Metadata metadata   `xml:"metadata"`
	Tracks   []trackXML `xml:"trk"`
}

type metadata struct {
	Time string `xml:"time"`
}

type trackXML struct {
	Name    string      `xml:"name"`
	Type    string      `xml:"type"`
	Segments []segmentXML `xml:"trkseg"`
}

type segmentXML struct {
	Points []trackPointXML `xml:"trkpt"`
}

type trackPointXML struct {
	Lat   string  `xml:"lat,attr"`
	Lon   string  `xml:"lon,attr"`
	Ele   float64 `xml:"ele"`
	Time  string  `xml:"time"`
}

// ParseFile reads a GPX file and returns the parsed track points.
func ParseFile(path string) (*RideStats, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read GPX file: %w", err)
	}

	var gpx gpxXML
	if err := xml.Unmarshal(data, &gpx); err != nil {
		return nil, fmt.Errorf("parse GPX XML: %w", err)
	}

	if len(gpx.Tracks) == 0 || len(gpx.Tracks[0].Segments) == 0 {
		return nil, fmt.Errorf("no track segments found in GPX")
	}

	segment := gpx.Tracks[0].Segments[0]
	points := make([]TrackPoint, 0, len(segment.Points))

	for _, p := range segment.Points {
		lat, err := parseFloat(p.Lat)
		if err != nil {
			continue
		}
		lon, err := parseFloat(p.Lon)
		if err != nil {
			continue
		}
		t, err := time.Parse(time.RFC3339, p.Time)
		if err != nil {
			continue
		}

		points = append(points, TrackPoint{
			Lat:       lat,
			Lon:       lon,
			Elevation: p.Ele,
			Time:      t,
		})
	}

	if len(points) == 0 {
		return nil, fmt.Errorf("no valid track points found")
	}

	stats := computeStats(points)
	if gpx.Tracks[0].Type != "" {
		stats.ActivityType = normalizeActivityType(gpx.Tracks[0].Type)
	} else {
		stats.ActivityType = "bicycle"
	}

	return stats, nil
}

func computeStats(points []TrackPoint) *RideStats {
	stats := &RideStats{
		Points:       points,
		StartTime:    points[0].Time,
		EndTime:      points[len(points)-1].Time,
		StartPoint:   points[0],
		EndPoint:     points[len(points)-1],
		MinElevation: points[0].Elevation,
		MaxElevation: points[0].Elevation,
	}

	stats.Duration = stats.EndTime.Sub(stats.StartTime)

	for i := 1; i < len(points); i++ {
		prev := points[i-1]
		curr := points[i]

		// Distance
		stats.DistanceKm += haversine(prev.Lat, prev.Lon, curr.Lat, curr.Lon)

		// Elevation
		if curr.Elevation > stats.MaxElevation {
			stats.MaxElevation = curr.Elevation
		}
		if curr.Elevation < stats.MinElevation {
			stats.MinElevation = curr.Elevation
		}

		diff := curr.Elevation - prev.Elevation
		if diff > 0 {
			stats.ElevationGain += diff
		} else {
			stats.ElevationLoss += -diff
		}
	}

	return stats
}

// haversine calculates the distance between two lat/lon points in kilometers.
func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0 // Earth radius in km
	phi1 := lat1 * math.Pi / 180
	phi2 := lat2 * math.Pi / 180
	deltaPhi := (lat2 - lat1) * math.Pi / 180
	deltaLambda := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(deltaPhi/2)*math.Sin(deltaPhi/2) +
		math.Cos(phi1)*math.Cos(phi2)*
			math.Sin(deltaLambda/2)*math.Sin(deltaLambda/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return R * c
}

func parseFloat(s string) (float64, error) {
	var f float64
	_, err := fmt.Sscanf(s, "%f", &f)
	return f, err
}

func normalizeActivityType(t string) string {
	switch t {
	case "ebikeride", "e-bike", "electric_bike":
		return "e-bike"
	case "ride", "bicycle", "cycling":
		return "bicycle"
	case "hike", "hiking", "walk", "walking":
		return "hike"
	default:
		return t
	}
}
