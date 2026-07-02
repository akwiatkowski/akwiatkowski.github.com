package e2e

import (
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// TestTagPostListRoweremLoads verifies the bicycle tag post list page returns 200
// and contains the expected page structure.
func TestTagPostListRoweremLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/wpisy-dla/tagu/rowerem.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	if !strings.Contains(html, "post-collection-config") {
		t.Error("page missing post-collection-config script")
	}
	if !strings.Contains(html, `"filterValue":"bicycle"`) {
		t.Error("page should filter by bicycle tag")
	}
	if !strings.Contains(html, "post_collection.js") {
		t.Error("page missing post_collection.js script")
	}
}

// TestTagPostListPieszoLoads verifies the hike tag post list page returns 200.
func TestTagPostListPieszoLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/wpisy-dla/tagu/pieszo.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	if !strings.Contains(html, `"filterValue":"hike"`) {
		t.Error("page should filter by hike tag")
	}
}

// TestTagPostListRoweremRendersCards verifies that post_collection.js fetches
// homepage.json, filters by the bicycle tag, and renders post cards.
func TestTagPostListRoweremRendersCards(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/wpisy-dla/tagu/rowerem.html")
	defer page.MustClose()

	// Wait for post cards to be rendered by JS
	err := waitForJS(page, `() => document.querySelectorAll('.post-card').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered on bicycle tag page")
	}

	count, _ := jsEvalInt(page, `() => document.querySelectorAll('.post-card').length`)
	t.Logf("Bicycle post cards: %d", count)

	if count == 0 {
		t.Error("expected at least one bicycle post card")
	}

	// Each card should have a title with a link
	title, _ := jsEval(page, `() => {
		var el = document.querySelector('.post-card .post-title a');
		return el ? el.textContent.trim() : '';
	}`)
	if title == "" {
		t.Error("first card has empty title")
	}
}

// TestTagPostListPieszoRendersCards verifies hike posts are rendered.
func TestTagPostListPieszoRendersCards(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/wpisy-dla/tagu/pieszo.html")
	defer page.MustClose()

	err := waitForJS(page, `() => document.querySelectorAll('.post-card').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered on hike tag page")
	}

	count, _ := jsEvalInt(page, `() => document.querySelectorAll('.post-card').length`)
	t.Logf("Hike post cards: %d", count)

	if count == 0 {
		t.Error("expected at least one hike post card")
	}
}

// TestTagPostListCardsHaveImages verifies rendered post cards include images.
func TestTagPostListCardsHaveImages(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/wpisy-dla/tagu/rowerem.html")
	defer page.MustClose()

	err := waitForJS(page, `() => document.querySelectorAll('.post-card').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered")
	}

	src, _ := jsEval(page, `() => {
		var img = document.querySelector('.post-card .post-image');
		return img ? (img.getAttribute('src') || '') : '';
	}`)
	if src == "" {
		t.Error("first card image has no src attribute")
	}
}

// TestTagPostListCardsHaveTagLinks verifies rendered cards show tag links
// resolved from the homepage.json tags map.
func TestTagPostListCardsHaveTagLinks(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/wpisy-dla/tagu/rowerem.html")
	defer page.MustClose()

	err := waitForJS(page, `() => document.querySelectorAll('.post-card').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered")
	}

	// Tag links should have href pointing to /wpisy-dla/tagu/
	href, _ := jsEval(page, `() => {
		var el = document.querySelector('.post-card .post-tags a');
		return el ? (el.getAttribute('href') || '') : '';
	}`)
	if href == "" {
		t.Error("no tag link found in first card")
	} else if !strings.Contains(href, "/wpisy-dla/tagu/") {
		t.Errorf("tag link href = %q, want /wpisy-dla/tagu/ prefix", href)
	}
}
