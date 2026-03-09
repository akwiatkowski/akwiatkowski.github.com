package e2e

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// TestAreaShowPageLoads verifies the area show page returns 200
// and contains the area-data JSON script with required fields.
func TestAreaShowPageLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/gmina/jablonowo_pomorskie.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	if !strings.Contains(html, `id="area-data"`) {
		t.Fatal("page missing area-data script")
	}
	if !strings.Contains(html, "area_show.js") {
		t.Error("page missing area_show.js script")
	}
}

// TestAreaShowJSONHasRequiredFields verifies the inlined area-data JSON
// contains all fields expected by area_show.js.
func TestAreaShowJSONHasRequiredFields(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/gmina/jablonowo_pomorskie.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	// Extract JSON from <script id="area-data" ...>...</script>
	start := strings.Index(html, `<script id="area-data" type="application/json">`)
	if start == -1 {
		t.Fatal("area-data script not found")
	}
	start = strings.Index(html[start:], ">") + start + 1
	end := strings.Index(html[start:], "</script>") + start
	jsonStr := html[start:end]

	var data map[string]json.RawMessage
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		t.Fatalf("failed to parse area-data JSON: %v", err)
	}

	requiredFields := []string{
		"slug", "name", "areaType", "areaTypeLabel",
		"postListUrl", "galleryUrl", "bbox",
		"posts", "photos",
	}
	for _, field := range requiredFields {
		if _, ok := data[field]; !ok {
			t.Errorf("area-data JSON missing required field %q", field)
		}
	}

	// Verify bbox has lowercase keys
	var bbox map[string]float64
	if err := json.Unmarshal(data["bbox"], &bbox); err != nil {
		t.Fatalf("failed to parse bbox: %v", err)
	}
	for _, key := range []string{"south", "north", "west", "east"} {
		if _, ok := bbox[key]; !ok {
			t.Errorf("bbox missing lowercase key %q", key)
		}
	}

	// Verify posts array is non-empty
	var posts []map[string]json.RawMessage
	if err := json.Unmarshal(data["posts"], &posts); err != nil {
		t.Fatalf("failed to parse posts: %v", err)
	}
	if len(posts) == 0 {
		t.Error("area-data should have at least one post")
	}

	// Verify post entries have required fields
	postFields := []string{"url", "slug", "title", "date", "tags", "card_image_url"}
	for _, field := range postFields {
		if _, ok := posts[0][field]; !ok {
			t.Errorf("post entry missing required field %q", field)
		}
	}

	// Verify photos array is non-empty
	var photos []map[string]json.RawMessage
	if err := json.Unmarshal(data["photos"], &photos); err != nil {
		t.Fatalf("failed to parse photos: %v", err)
	}
	if len(photos) == 0 {
		t.Error("area-data should have at least one photo")
	}
}

// TestAreaShowRendersPostsViaJS verifies that area_show.js renders
// the posts section with post cards from the area-data JSON.
func TestAreaShowRendersPostsViaJS(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/gmina/jablonowo_pomorskie.html")
	defer page.MustClose()

	// Wait for Preact to render the posts section
	err := waitForJS(page, `() => document.querySelectorAll('.post-card-link').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered on area show page")
	}

	count, _ := jsEvalInt(page, `() => document.querySelectorAll('.post-card-link').length`)
	t.Logf("Area post cards: %d", count)

	if count == 0 {
		t.Error("expected at least one post card on area show page")
	}

	// Verify post card has a title
	title, _ := jsEval(page, `() => {
		var el = document.querySelector('.post-card-title');
		return el ? el.textContent.trim() : '';
	}`)
	if title == "" {
		t.Error("first post card has empty title")
	}
}

// TestAreaShowRendersStatsViaJS verifies that the stats bar is rendered
// with non-zero values.
func TestAreaShowRendersStatsViaJS(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/gmina/jablonowo_pomorskie.html")
	defer page.MustClose()

	// Wait for stats bar to render
	err := waitForJS(page, `() => document.querySelectorAll('.stats-bar').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("stats bar not rendered on area show page")
	}

	// Stats should show non-zero post count
	statsText, _ := jsEval(page, `() => {
		var el = document.querySelector('.stats-inline');
		return el ? el.textContent.trim() : '';
	}`)
	if statsText == "" {
		t.Error("stats bar has empty text")
	}
	if strings.Contains(statsText, "0 wypraw") {
		t.Error("stats bar shows 0 posts, expected non-zero")
	}
}
