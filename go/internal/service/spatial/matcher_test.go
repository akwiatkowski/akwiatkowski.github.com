package spatial

import (
	"testing"

	"odkrywajac/internal/model"
)

// triangleAreas returns a small set of synthetic areas for testing.
// A single triangle polygon covering roughly the area around (52.0, 17.0).
func triangleAreas() map[string][]ExternalArea {
	return map[string][]ExternalArea{
		"towns": {
			{
				Slug: "test-town",
				Name: "Test Town",
				Terc: "0001",
				// Triangle in [lat, lon] order: (51.9, 16.9), (52.1, 16.9), (52.0, 17.1)
				Polygon: [][]float64{
					{51.9, 16.9},
					{52.1, 16.9},
					{52.0, 17.1},
				},
			},
		},
		"counties":      {},
		"voivodeships":  {},
		"meso_regions":  {},
		"macro_regions": {},
	}
}

func loadTestAreas(_ string) (map[string][]ExternalArea, error) {
	return triangleAreas(), nil
}

func TestMatcher_MatchRoute_Crossing(t *testing.T) {
	matcher, err := NewMatcher("", loadTestAreas)
	if err != nil {
		t.Fatalf("NewMatcher: %v", err)
	}
	defer matcher.Close()

	// Route that crosses through the triangle
	segments := [][]model.LatLon{
		{
			{Lat: 52.0, Lon: 16.8}, // west of triangle
			{Lat: 52.0, Lon: 17.0}, // inside triangle
			{Lat: 52.0, Lon: 17.2}, // east of triangle
		},
	}

	result := matcher.MatchRoute(segments, "bicycle")
	if len(result.Segments) != 1 {
		t.Fatalf("expected 1 segment, got %d", len(result.Segments))
	}

	seg := result.Segments[0]
	if seg.Type != "bicycle" {
		t.Errorf("type: got %q, want %q", seg.Type, "bicycle")
	}
	if seg.TotalDistanceM < 1000 {
		t.Errorf("total distance too small: %.1fm", seg.TotalDistanceM)
	}
	if len(seg.Towns) == 0 {
		t.Error("expected at least one town match")
	} else {
		if seg.Towns[0].Slug != "test-town" {
			t.Errorf("town slug: got %q, want %q", seg.Towns[0].Slug, "test-town")
		}
		if seg.Towns[0].DistanceM <= 0 {
			t.Error("expected positive distance through town")
		}
		if seg.Towns[0].DistancePercent <= 0 || seg.Towns[0].DistancePercent > 100 {
			t.Errorf("unexpected distance percent: %f", seg.Towns[0].DistancePercent)
		}
	}
	if len(seg.TouchedTowns) == 0 {
		t.Error("expected at least one touched town")
	}
}

func TestMatcher_MatchRoute_NoIntersection(t *testing.T) {
	matcher, err := NewMatcher("", loadTestAreas)
	if err != nil {
		t.Fatalf("NewMatcher: %v", err)
	}
	defer matcher.Close()

	// Route far away from the triangle
	segments := [][]model.LatLon{
		{
			{Lat: 54.0, Lon: 20.0},
			{Lat: 54.1, Lon: 20.1},
		},
	}

	result := matcher.MatchRoute(segments, "hike")
	if len(result.Segments) != 1 {
		t.Fatalf("expected 1 segment, got %d", len(result.Segments))
	}
	seg := result.Segments[0]
	if len(seg.Towns) != 0 {
		t.Errorf("expected no town matches, got %d", len(seg.Towns))
	}
	if len(seg.TouchedTowns) != 0 {
		t.Errorf("expected no touched towns, got %d", len(seg.TouchedTowns))
	}
}

func TestMatcher_MatchPoint_Inside(t *testing.T) {
	matcher, err := NewMatcher("", loadTestAreas)
	if err != nil {
		t.Fatalf("NewMatcher: %v", err)
	}
	defer matcher.Close()

	// Point inside the triangle (centroid ≈ 52.0, 16.97)
	result := matcher.MatchPoint(52.0, 16.95)
	if len(result.Towns) == 0 {
		t.Error("expected point to be inside test-town")
	} else if result.Towns[0].Slug != "test-town" {
		t.Errorf("town slug: got %q, want %q", result.Towns[0].Slug, "test-town")
	}
}

func TestMatcher_MatchPoint_Outside(t *testing.T) {
	matcher, err := NewMatcher("", loadTestAreas)
	if err != nil {
		t.Fatalf("NewMatcher: %v", err)
	}
	defer matcher.Close()

	// Point outside the triangle
	result := matcher.MatchPoint(54.0, 20.0)
	if len(result.Towns) != 0 {
		t.Errorf("expected no matches for outside point, got %d", len(result.Towns))
	}
}

func TestBBoxOverlaps(t *testing.T) {
	a := bbox{south: 50, north: 55, west: 15, east: 20}

	tests := []struct {
		name string
		b    bbox
		want bool
	}{
		{"overlapping", bbox{52, 57, 18, 22}, true},
		{"contained", bbox{51, 54, 16, 19}, true},
		{"disjoint north", bbox{56, 60, 15, 20}, false},
		{"disjoint south", bbox{40, 49, 15, 20}, false},
		{"disjoint east", bbox{50, 55, 21, 25}, false},
		{"disjoint west", bbox{50, 55, 10, 14}, false},
		{"touching edge", bbox{55, 60, 15, 20}, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := bboxOverlaps(a, tt.b); got != tt.want {
				t.Errorf("bboxOverlaps: got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestNormalizeToLonLat(t *testing.T) {
	// Input in [lat, lon] order (lat > 40 for Poland)
	input := [][]float64{{52.0, 17.0}, {53.0, 18.0}}
	result := normalizeToLonLat(input)
	if result[0][0] != 17.0 || result[0][1] != 52.0 {
		t.Errorf("expected [17.0, 52.0], got [%f, %f]", result[0][0], result[0][1])
	}

	// Input already in [lon, lat] order (first value < 40)
	input2 := [][]float64{{17.0, 52.0}, {18.0, 53.0}}
	result2 := normalizeToLonLat(input2)
	if result2[0][0] != 17.0 || result2[0][1] != 52.0 {
		t.Errorf("expected [17.0, 52.0], got [%f, %f]", result2[0][0], result2[0][1])
	}
}
