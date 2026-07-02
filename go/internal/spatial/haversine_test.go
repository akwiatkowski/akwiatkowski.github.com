package spatial

import (
	"math"
	"testing"
)

func TestHaversineM_KnownDistance(t *testing.T) {
	// Poznań (52.4064, 16.9252) → Warsaw (52.2297, 21.0122) ≈ 278 km
	dist := HaversineM(52.4064, 16.9252, 52.2297, 21.0122)
	if math.Abs(dist-278_000) > 5000 {
		t.Errorf("Poznań→Warsaw: got %.0fm, want ~278000m (±5km)", dist)
	}
}

func TestHaversineM_SamePoint(t *testing.T) {
	dist := HaversineM(52.0, 17.0, 52.0, 17.0)
	if dist != 0 {
		t.Errorf("same point: got %f, want 0", dist)
	}
}

func TestLinestringDistanceM_ThreePoints(t *testing.T) {
	// Three points in GEOS order (lon, lat): A → B → C
	// A=(17.0, 52.0), B=(17.1, 52.0), C=(17.2, 52.0) — east along ~52°N
	lons := []float64{17.0, 17.1, 17.2}
	lats := []float64{52.0, 52.0, 52.0}
	dist := LinestringDistanceM(lons, lats)

	segDist := HaversineM(52.0, 17.0, 52.0, 17.1)
	expected := segDist * 2

	if math.Abs(dist-expected) > 1 {
		t.Errorf("3-point linestring: got %.1fm, want %.1fm", dist, expected)
	}
}

func TestLinestringDistanceM_TooFewPoints(t *testing.T) {
	if d := LinestringDistanceM(nil, nil); d != 0 {
		t.Errorf("nil: got %f, want 0", d)
	}
	if d := LinestringDistanceM([]float64{17.0}, []float64{52.0}); d != 0 {
		t.Errorf("single point: got %f, want 0", d)
	}
}
