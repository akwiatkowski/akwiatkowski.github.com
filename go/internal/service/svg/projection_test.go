package svg

import (
	"math"
	"testing"
)

func TestTileCoordsRoundTrip(t *testing.T) {
	lat, lon := 52.4, 16.9 // Poznan, Poland
	zoom := 10

	tx, ty := TileCoords(lat, lon, zoom)
	latBack, lonBack := GeoCoords(tx, ty, zoom)

	if math.Abs(latBack-lat) > 0.001 {
		t.Errorf("lat roundtrip: got %f, want %f", latBack, lat)
	}
	if math.Abs(lonBack-lon) > 0.001 {
		t.Errorf("lon roundtrip: got %f, want %f", lonBack, lon)
	}
}

func TestLatLonToPixel(t *testing.T) {
	px, py := LatLonToPixel(52.4, 16.9, 10)

	// At zoom 10, Poland should produce pixel coords in a reasonable range
	if px < 100000 || px > 200000 {
		t.Errorf("px out of expected range: %f", px)
	}
	if py < 80000 || py > 200000 {
		t.Errorf("py out of expected range: %f", py)
	}
}

func TestPixelRoundTrip(t *testing.T) {
	lat, lon := 52.4, 16.9
	zoom := 10

	px, py := LatLonToPixel(lat, lon, zoom)
	latBack, lonBack := PixelToLatLon(px, py, zoom)

	if math.Abs(latBack-lat) > 0.0001 {
		t.Errorf("lat roundtrip: got %f, want %f", latBack, lat)
	}
	if math.Abs(lonBack-lon) > 0.0001 {
		t.Errorf("lon roundtrip: got %f, want %f", lonBack, lon)
	}
}

func TestComputeMapBounds(t *testing.T) {
	points := [][2]float64{
		{52.0, 16.0},
		{53.0, 17.0},
	}
	bounds := ComputeMapBounds(points, 10, 80)

	if bounds.Width() <= 0 {
		t.Error("bounds width should be positive")
	}
	if bounds.Height() <= 0 {
		t.Error("bounds height should be positive")
	}
}
