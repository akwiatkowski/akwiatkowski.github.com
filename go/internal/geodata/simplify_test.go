package geodata

import (
	"math"
	"testing"
)

func TestSimplify_ReducesPoints(t *testing.T) {
	// A zigzag line where middle points deviate slightly from the straight line
	coords := [][]float64{
		{0, 0},
		{1, 0.0005}, // small deviation — within tolerance 0.001
		{2, 0},
		{3, 0.0005},
		{4, 0},
		{5, 0.005}, // larger deviation — exceeds tolerance 0.001
		{6, 0},
	}

	result := Simplify(coords, 0.001)

	if len(result) >= len(coords) {
		t.Errorf("expected fewer points than %d, got %d", len(coords), len(result))
	}
	// First and last points must be preserved
	if result[0][0] != 0 || result[0][1] != 0 {
		t.Errorf("first point not preserved: %v", result[0])
	}
	if result[len(result)-1][0] != 6 || result[len(result)-1][1] != 0 {
		t.Errorf("last point not preserved: %v", result[len(result)-1])
	}
}

func TestSimplify_PreservesSignificantPoints(t *testing.T) {
	// Triangle — all points are significant
	coords := [][]float64{
		{0, 0},
		{5, 10},
		{10, 0},
	}

	result := Simplify(coords, 0.001)

	if len(result) != 3 {
		t.Errorf("expected 3 points for triangle, got %d", len(result))
	}
}

func TestSimplify_LessThan3Points(t *testing.T) {
	// Two points — returned as-is
	coords := [][]float64{{0, 0}, {1, 1}}
	result := Simplify(coords, 0.001)
	if len(result) != 2 {
		t.Errorf("expected 2 points, got %d", len(result))
	}

	// One point
	single := [][]float64{{5, 5}}
	result = Simplify(single, 0.001)
	if len(result) != 1 {
		t.Errorf("expected 1 point, got %d", len(result))
	}

	// Empty
	result = Simplify(nil, 0.001)
	if len(result) != 0 {
		t.Errorf("expected 0 points, got %d", len(result))
	}
}

func TestSimplify_ZeroTolerance(t *testing.T) {
	// With tolerance=0, only collinear points are removed
	coords := [][]float64{
		{0, 0},
		{1, 1}, // collinear
		{2, 2}, // collinear
		{3, 3},
	}

	result := Simplify(coords, 0)
	// All points are collinear, so only endpoints should remain
	if len(result) != 2 {
		t.Errorf("expected 2 points for collinear line with tolerance=0, got %d: %v", len(result), result)
	}
}

func TestSimplify_SquarePreserved(t *testing.T) {
	// Square — all corners are significant
	coords := [][]float64{
		{0, 0},
		{0, 10},
		{10, 10},
		{10, 0},
	}

	result := Simplify(coords, 0.001)
	if len(result) != 4 {
		t.Errorf("expected 4 points for square, got %d", len(result))
	}
}

func TestPerpendicularDistance(t *testing.T) {
	// Point directly above the midpoint of a horizontal line
	dist := perpendicularDistance(
		[]float64{5, 3}, // point
		[]float64{0, 0}, // line start
		[]float64{10, 0}, // line end
	)
	if math.Abs(dist-3.0) > 1e-10 {
		t.Errorf("expected distance 3.0, got %f", dist)
	}
}

func TestPerpendicularDistance_SameStartEnd(t *testing.T) {
	// Degenerate line (single point) — returns direct distance
	dist := perpendicularDistance(
		[]float64{3, 4},
		[]float64{0, 0},
		[]float64{0, 0},
	)
	expected := 5.0 // sqrt(9+16)
	if math.Abs(dist-expected) > 1e-10 {
		t.Errorf("expected distance %f, got %f", expected, dist)
	}
}
