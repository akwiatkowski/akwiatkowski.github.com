package svg

import (
	"math"
	"testing"
)

func TestFitZoom(t *testing.T) {
	const target = postMapFitTarget // 1000 - 2*BoundsPadding

	tests := []struct {
		name                           string
		latMin, latMax, lonMin, lonMax float64
		want                           int
	}{
		{
			// Real trip bbox (2026-06-20). Fits ~z12 at 1000px width.
			name: "warmia bike trip", latMin: 53.9142, latMax: 54.1279, lonMin: 20.5740, lonMax: 20.8974,
			want: 12,
		},
		{
			// Whole of Poland → low zoom.
			name: "poland wide", latMin: 49.0, latMax: 54.8, lonMin: 14.1, lonMax: 24.1,
			want: 7,
		},
		{
			// Degenerate: single point → most detail (clamped to max).
			name: "single point", latMin: 52.4, latMax: 52.4, lonMin: 16.9, lonMax: 16.9,
			want: postMapMaxZoom,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := FitZoom(tc.latMin, tc.latMax, tc.lonMin, tc.lonMax, target, postMapMinZoom, postMapMaxZoom)
			if got != tc.want {
				t.Errorf("FitZoom(%s) = %d, want %d", tc.name, got, tc.want)
			}
		})
	}
}

// Mirror the post-map sizing constants used by view.PostMapSVGs so this
// package-local test exercises the same target the renderer uses.
const (
	postMapFitTarget = 1000.0 - 2*BoundsPadding
	postMapMinZoom   = 6
	postMapMaxZoom   = 16
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
