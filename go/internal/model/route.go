package model

import "math"

// Route holds coordinate segments for a post's route.
type Route struct {
	Type     string     // "bicycle", "hike", "train", etc.
	Segments [][]LatLon // array of segments, each segment is a sequence of points
}

// LatLon is a geographic coordinate pair.
type LatLon struct {
	Lat float64
	Lon float64
}

// CoordRange is a bounding box defined by lat/lon ranges.
type CoordRange struct {
	LatFrom, LatTo float64
	LonFrom, LonTo float64
}

// Contains checks if a point falls within this range.
func (r CoordRange) Contains(lat, lon float64) bool {
	return lat >= r.LatFrom && lat <= r.LatTo && lon >= r.LonFrom && lon <= r.LonTo
}

// Center returns the center point of the range.
func (r CoordRange) Center() LatLon {
	return LatLon{
		Lat: (r.LatFrom + r.LatTo) / 2,
		Lon: (r.LonFrom + r.LonTo) / 2,
	}
}

// Merge returns the smallest CoordRange containing both ranges.
func (r CoordRange) Merge(other CoordRange) CoordRange {
	return CoordRange{
		LatFrom: math.Min(r.LatFrom, other.LatFrom),
		LatTo:   math.Max(r.LatTo, other.LatTo),
		LonFrom: math.Min(r.LonFrom, other.LonFrom),
		LonTo:   math.Max(r.LonTo, other.LonTo),
	}
}
