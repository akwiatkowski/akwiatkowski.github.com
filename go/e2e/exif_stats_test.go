package e2e

import (
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// TestExifStatsPageLoads verifies the EXIF stats page renders with expected HTML structure.
func TestExifStatsPageLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/statystyki_exif.html")
	if err != nil {
		t.Fatalf("GET /statystyki_exif.html failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	// Page structure expected by exif_stats.js
	requiredIDs := []string{
		"yearChart", "publishedRatioChart",
		"cameraChart", "lensChart",
		"focalChart", "wideTeleChart",
		"apertureChart", "isoChart",
		"hourChart", "dayOfWeekChart",
	}
	for _, id := range requiredIDs {
		if !strings.Contains(html, `id="`+id+`"`) {
			t.Errorf("missing canvas element #%s", id)
		}
	}

	// Both JS files must be loaded in order
	if !strings.Contains(html, "focal_heatmap.js") {
		t.Error("missing focal_heatmap.js script reference")
	}
	if !strings.Contains(html, "exif_stats.js") {
		t.Error("missing exif_stats.js script reference")
	}
}

// TestExifStatsChartsRender verifies that charts are rendered by JS after loading photos.json.
func TestExifStatsChartsRender(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/statystyki_exif.html")
	defer page.MustClose()

	// Wait for photos.json to load and charts to render.
	// The yearChart canvas gets drawn by Chart.js — check that it has non-zero dimensions.
	err := waitForJS(page, `() => {
		var el = document.getElementById('totalPhotos');
		return el && el.textContent !== '0' && el.textContent !== '';
	}`, 15*time.Second)
	if err != nil {
		t.Fatal("stats cards never populated — photos.json may have failed to load")
	}

	// Verify total photos count is reasonable
	totalPhotos, _ := jsEval(page, `() => document.getElementById('totalPhotos').textContent`)
	total := parseIntFromText(totalPhotos)
	t.Logf("Total photos with EXIF: %d", total)
	if total < 100 {
		t.Errorf("totalPhotos = %d, expected at least 100", total)
	}

	// Verify stat cards are populated (not showing placeholder dashes)
	statIDs := []string{"modalFocal", "avgAperture", "topLens", "topCamera"}
	for _, id := range statIDs {
		val, _ := jsEval(page, `() => document.getElementById('`+id+`').textContent`)
		if val == "" || val == "—" || val == "\u2014" {
			t.Errorf("#%s still shows placeholder: %q", id, val)
		}
	}

	// Verify the streamgraph canvas (wideTeleChart) has been drawn.
	// A drawn canvas has non-zero image data; an empty one is all transparent.
	drawn, _ := jsEvalBool(page, `() => {
		var c = document.getElementById('wideTeleChart');
		if (!c) return false;
		var ctx = c.getContext('2d');
		var data = ctx.getImageData(0, 0, c.width, c.height).data;
		for (var i = 3; i < data.length; i += 4) {
			if (data[i] > 0) return true;
		}
		return false;
	}`)
	if !drawn {
		t.Error("wideTeleChart canvas is empty — streamgraph not rendered")
	}
}

// TestExifStatsFiltersExist verifies filter controls are present.
func TestExifStatsFiltersExist(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/statystyki_exif.html")
	defer page.MustClose()

	// Wait for filters to be populated with options
	err := waitForJS(page, `() => document.getElementById('yearFilter').options.length > 1`, 15*time.Second)
	if err != nil {
		t.Fatal("yearFilter never populated with options")
	}

	// Check camera and lens filters also have options
	cameraOpts, _ := jsEvalInt(page, `() => document.getElementById('cameraFilter').options.length`)
	lensOpts, _ := jsEvalInt(page, `() => document.getElementById('lensFilter').options.length`)

	t.Logf("Filter options: year=%d+, camera=%d, lens=%d",
		1, cameraOpts, lensOpts)

	if cameraOpts < 2 {
		t.Errorf("cameraFilter has %d options, expected at least 2", cameraOpts)
	}
	if lensOpts < 2 {
		t.Errorf("lensFilter has %d options, expected at least 2", lensOpts)
	}
}
