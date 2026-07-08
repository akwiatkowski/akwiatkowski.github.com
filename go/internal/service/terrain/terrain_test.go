package terrain

import (
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseRouteColor(t *testing.T) {
	cases := []struct {
		in      string
		r, g, b uint8
	}{
		{"51,136,255", 51, 136, 255},
		{"rgb(0,70,240)", 0, 70, 240},
		{" 10, 20 , 30 ", 10, 20, 30},
		{"garbage", 51, 136, 255}, // falls back to default blue
		{"1,2", 51, 136, 255},     // wrong arity → default
		{"300,0,0", 51, 136, 255}, // out of range → default
	}
	for _, c := range cases {
		got := parseRouteColor(c.in)
		if got.R != c.r || got.G != c.g || got.B != c.b || got.A != 255 {
			t.Errorf("parseRouteColor(%q) = %v, want {%d %d %d 255}", c.in, got, c.r, c.g, c.b)
		}
	}
}

func TestPixelToMercator(t *testing.T) {
	// At zoom 0 the world is one 256px tile spanning [-R,R] on both axes.
	cases := []struct {
		px, py       float64
		wantX, wantY float64
	}{
		{0, 0, -mercatorR, mercatorR},     // top-left → (-R, +R)
		{256, 256, mercatorR, -mercatorR}, // bottom-right → (+R, -R)
		{128, 128, 0, 0},                  // center → origin
	}
	for _, c := range cases {
		x, y := pixelToMercator(c.px, c.py, 0)
		if math.Abs(x-c.wantX) > 1e-6 || math.Abs(y-c.wantY) > 1e-6 {
			t.Errorf("pixelToMercator(%.0f,%.0f,0) = (%.3f,%.3f), want (%.3f,%.3f)",
				c.px, c.py, x, y, c.wantX, c.wantY)
		}
	}
}

func TestSrtmTilesFor(t *testing.T) {
	dir := t.TempDir()
	// Only N52E017 exists on disk.
	tile := filepath.Join(dir, "N52E017.hgt.gz")
	if err := os.WriteFile(tile, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	// A box inside 52..53N, 17..18E must pick up exactly that tile.
	got := srtmTilesFor(52.3, 52.6, 17.2, 17.8, dir)
	if len(got) != 1 || !strings.HasSuffix(got[0], "N52E017.hgt.gz") || !strings.HasPrefix(got[0], "/vsigzip/") {
		t.Errorf("srtmTilesFor inside tile = %v, want single /vsigzip/…N52E017.hgt.gz", got)
	}

	// A box in a cell with no tile on disk returns nothing.
	if got := srtmTilesFor(48.1, 48.2, 10.1, 10.2, dir); len(got) != 0 {
		t.Errorf("srtmTilesFor over missing tile = %v, want empty", got)
	}
}

func TestSampleLinear(t *testing.T) {
	// A single segment longer than the spacing gets densified, staying on-line.
	line := [][2]float64{{0, 0}, {10, 0}}
	got := sampleLinear(line, 1)
	if len(got) <= len(line) {
		t.Errorf("sampleLinear did not densify: got %d points from %d", len(got), len(line))
	}
	if got[0] != line[0] {
		t.Errorf("sampled path does not start at first point: %v", got[0])
	}
	last := got[len(got)-1]
	if math.Abs(last[0]-10) > 1e-9 || math.Abs(last[1]) > 1e-9 {
		t.Errorf("sampled path does not end at last point: %v", last)
	}
	for _, p := range got {
		if math.Abs(p[1]) > 1e-6 {
			t.Errorf("sampled point off the straight line: %v", p)
		}
	}

	// Fewer than 2 points: returned unchanged.
	if got := sampleLinear([][2]float64{{1, 1}}, 1); len(got) != 1 {
		t.Errorf("sampleLinear with 1 point returned %d", len(got))
	}
}

func TestRdpSimplify(t *testing.T) {
	// Collinear points collapse to the two endpoints.
	line := [][2]float64{{0, 0}, {5, 0}, {10, 0}}
	if got := rdpSimplify(line, 0.5); len(got) != 2 {
		t.Errorf("rdpSimplify collinear = %d points, want 2", len(got))
	}
	// A point outside tolerance is kept.
	bent := [][2]float64{{0, 0}, {5, 5}, {10, 0}}
	if got := rdpSimplify(bent, 0.5); len(got) != 3 {
		t.Errorf("rdpSimplify bent = %d points, want 3", len(got))
	}
}

func TestParseHstore(t *testing.T) {
	got := parseHstore(`"waterway"=>"stream","name"=>"Rów A"`)
	if got["waterway"] != "stream" || got["name"] != "Rów A" {
		t.Errorf("parseHstore basic = %v", got)
	}
	// Escaped quotes inside a value.
	esc := parseHstore(`"name"=>"A \"B\" C"`)
	if esc["name"] != `A "B" C` {
		t.Errorf("parseHstore escaped = %q, want %q", esc["name"], `A "B" C`)
	}
	if len(parseHstore("")) != 0 {
		t.Error("parseHstore(\"\") should be empty")
	}
}

func TestFlattenTags(t *testing.T) {
	tags := flattenTags(map[string]any{
		"natural":    "wood",
		"osm_id":     "123", // dropped
		"other_tags": `"leaf_type"=>"broadleaved","natural"=>"scrub"`,
		"empty":      "", // skipped
	})
	if tags["natural"] != "wood" { // dedicated column wins over other_tags
		t.Errorf("natural = %q, want wood", tags["natural"])
	}
	if tags["leaf_type"] != "broadleaved" {
		t.Errorf("leaf_type = %q, want broadleaved", tags["leaf_type"])
	}
	if _, ok := tags["osm_id"]; ok {
		t.Error("osm_id should be dropped")
	}
	if _, ok := tags["empty"]; ok {
		t.Error("empty value should be skipped")
	}
}

func TestBuildGeometry(t *testing.T) {
	if _, ok := buildGeometry("Point", []byte(`[18.5,53.4]`)); !ok {
		t.Error("Point failed")
	}
	if g, ok := buildGeometry("Polygon", []byte(`[[[0,0],[1,0],[1,1],[0,0]]]`)); !ok || g == nil {
		t.Error("Polygon failed")
	}
	if g, ok := buildGeometry("LineString", []byte(`[[0,0],[1,1]]`)); !ok || g == nil {
		t.Error("LineString failed")
	}
	if _, ok := buildGeometry("GeometryCollection", []byte(`[]`)); ok {
		t.Error("unsupported type should return ok=false")
	}
}
