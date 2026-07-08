package terrain

import (
	"encoding/binary"
	"fmt"
	"math"
)

// elevationSampler answers "what's the elevation at this lat/lon?" from the 10m
// GUGiK NMT tiles, decoded into memory. It's the shared basis for the elevation
// profile chart and the terrain-gradient route coloring — both need elevation
// sampled along a route without shelling out per point.
type elevationSampler struct {
	tiles []nmtGrid
}

// nmtGrid is one decoded 10m tile: its raw int16 samples plus georeferencing.
type nmtGrid struct {
	data   []int16
	minLon float64
	maxLat float64
	xstep  float64
	ystep  float64
	nx     int
	ny     int
	scale  float64
}

// newElevationSampler loads the NMT tiles covering the lat/lon box into memory.
// Returns an error if no 10m tiles cover the area (caller may then skip the
// elevation-dependent outputs).
func newElevationSampler(latMin, latMax, lonMin, lonMax float64, dtmDir string) (*elevationSampler, error) {
	paths := nmtTilesFor(latMin, latMax, lonMin, lonMax, dtmDir)
	if len(paths) == 0 {
		return nil, fmt.Errorf("no 10m NMT tiles cover lat %.3f..%.3f lon %.3f..%.3f", latMin, latMax, lonMin, lonMax)
	}
	s := &elevationSampler{}
	for _, gzPath := range paths {
		side := gzPath[:len(gzPath)-len(".i16.gz")] + ".json"
		meta, err := readNMTSidecar(side)
		if err != nil {
			return nil, err
		}
		raw, err := gunzipBytes(gzPath, int64(meta.Nx)*int64(meta.Ny)*2)
		if err != nil {
			return nil, err
		}
		n := len(raw) / 2
		data := make([]int16, n)
		for i := 0; i < n; i++ {
			// Reinterpret two little-endian bytes as signed int16 (the tile's
			// on-disk format); the conversion is the intended two's-complement
			// bit reinterpretation, not an overflow.
			data[i] = int16(binary.LittleEndian.Uint16(raw[2*i:])) //nolint:gosec // G115: intentional int16 bit reinterpretation
		}
		s.tiles = append(s.tiles, nmtGrid{
			data: data, minLon: meta.MinLon, maxLat: meta.MaxLat,
			xstep: meta.Xstep, ystep: meta.Ystep, nx: meta.Nx, ny: meta.Ny, scale: meta.Scale,
		})
	}
	return s, nil
}

// at returns the elevation in meters at the given point, or ok=false if no tile
// covers it or the sample is no-data. Nearest-sample (10m is fine for profiles).
func (s *elevationSampler) at(lat, lon float64) (float64, bool) {
	for _, t := range s.tiles {
		col := int((lon-t.minLon)/t.xstep + 0.5)
		row := int((t.maxLat-lat)/t.ystep + 0.5)
		if col < 0 || col >= t.nx || row < 0 || row >= t.ny {
			continue
		}
		v := t.data[row*t.nx+col]
		if int(v) == nmtNoData {
			return 0, false
		}
		return float64(v) * t.scale, true
	}
	return 0, false
}

// haversineKm returns the great-circle distance between two lat/lon points in
// kilometers — used to build the distance axis of the elevation profile.
func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	const earthKm = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earthKm * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}
