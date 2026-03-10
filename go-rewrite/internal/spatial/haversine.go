package spatial

import "math"

const earthRadiusM = 6371000.0 // Earth radius in meters

// HaversineM returns the distance in meters between two geographic points
// specified by their latitude and longitude in degrees.
func HaversineM(lat1, lon1, lat2, lon2 float64) float64 {
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusM * c
}

// LinestringDistanceM computes the total Haversine distance in meters along a
// sequence of GEOS-order coordinates (lon, lat). Returns 0 for fewer than 2 points.
func LinestringDistanceM(lons, lats []float64) float64 {
	if len(lons) < 2 {
		return 0
	}
	var total float64
	for i := 1; i < len(lons); i++ {
		total += HaversineM(lats[i-1], lons[i-1], lats[i], lons[i])
	}
	return total
}

// LatLonLinestringDistanceM computes the total Haversine distance in meters along
// a sequence of LatLon coordinates (lat, lon order as in model.LatLon).
func LatLonLinestringDistanceM(lats, lons []float64) float64 {
	return LinestringDistanceM(lons, lats)
}
