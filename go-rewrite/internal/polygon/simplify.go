// Package polygon generates simplified GeoJSON polygon files from external
// area data for use in area show pages.
package polygon

import "math"

// Simplify applies the Douglas-Peucker algorithm to reduce the number of
// points in a polygon while preserving its shape within the given tolerance.
// Each point is a [lat, lon] pair (matching the input YAML format).
// Returns the original points if there are fewer than 3.
func Simplify(coords [][]float64, tolerance float64) [][]float64 {
	if len(coords) < 3 {
		return coords
	}
	return douglasPeucker(coords, tolerance)
}

// douglasPeucker recursively simplifies a polyline by removing points that
// fall within the tolerance distance of the line connecting the endpoints.
func douglasPeucker(points [][]float64, tolerance float64) [][]float64 {
	if len(points) <= 2 {
		return points
	}

	// Find the point with the maximum distance from the line
	maxDist := 0.0
	maxIdx := 0
	start := points[0]
	end := points[len(points)-1]

	for i := 1; i < len(points)-1; i++ {
		dist := perpendicularDistance(points[i], start, end)
		if dist > maxDist {
			maxDist = dist
			maxIdx = i
		}
	}

	// If max distance exceeds tolerance, recursively simplify both halves
	if maxDist > tolerance {
		left := douglasPeucker(points[:maxIdx+1], tolerance)
		right := douglasPeucker(points[maxIdx:], tolerance)
		// Combine results, avoiding duplicate of the split point
		return append(left[:len(left)-1], right...)
	}

	// All intermediate points are within tolerance — keep only endpoints
	return [][]float64{start, end}
}

// perpendicularDistance calculates the perpendicular distance from a point
// to the line defined by lineStart and lineEnd. Each argument is [lat, lon].
func perpendicularDistance(point, lineStart, lineEnd []float64) float64 {
	dx := lineEnd[0] - lineStart[0]
	dy := lineEnd[1] - lineStart[1]

	// If start and end are the same point, return direct distance
	lineLenSq := dx*dx + dy*dy
	if lineLenSq == 0 {
		px := point[0] - lineStart[0]
		py := point[1] - lineStart[1]
		return math.Sqrt(px*px + py*py)
	}

	// Calculate perpendicular distance using the cross product formula:
	// |AB × AP| / |AB|
	// where AB is the line vector and AP is point relative to line start
	num := math.Abs(dy*(point[0]-lineStart[0]) - dx*(point[1]-lineStart[1]))
	return num / math.Sqrt(lineLenSq)
}
