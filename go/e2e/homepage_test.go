package e2e

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestHomepageLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/index.html")
	if err != nil {
		t.Fatalf("GET /index.html failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	if !strings.Contains(html, "<title>") {
		t.Error("page missing <title> tag")
	}
	if !strings.Contains(html, "Odkrywając Polskę") {
		t.Error("page missing site title")
	}
	if !strings.Contains(html, "home-page") {
		t.Error("page missing home-page wrapper class")
	}
}

func TestHomepageJSONLoads(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/jsons/homepage.json")
	if err != nil {
		t.Fatalf("GET /jsons/homepage.json failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}

	// homepage.json uses Crystal's flat-array shape: tags and each area type are
	// arrays of {slug, url, name}; there is no nested "areas" map.
	type lookupEntry struct {
		Slug string `json:"slug"`
		URL  string `json:"url"`
		Name string `json:"name"`
	}
	var data struct {
		Posts []struct {
			URL        string   `json:"url"`
			Title      string   `json:"title"`
			Date       string   `json:"date"`
			Time       string   `json:"time"`
			DistanceKm int      `json:"distance_km"`
			Tags       []string `json:"tags"`
		} `json:"posts"`
		Tags        []lookupEntry `json:"tags"`
		Towns       []lookupEntry `json:"towns"`
		Voivodeships []lookupEntry `json:"voivodeships"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		t.Fatalf("JSON decode failed: %v", err)
	}

	if len(data.Posts) == 0 {
		t.Error("posts array is empty")
	}
	if len(data.Tags) == 0 {
		t.Error("tags array is empty")
	}
	if len(data.Towns) == 0 {
		t.Error("towns array is empty")
	}

	// Verify first post has required fields
	if len(data.Posts) > 0 {
		post := data.Posts[0]
		if post.URL == "" {
			t.Error("first post missing URL")
		}
		if post.Title == "" {
			t.Error("first post missing title")
		}
		if post.Date == "" {
			t.Error("first post missing date")
		}
		if post.Time == "" {
			t.Error("first post missing time (RFC3339)")
		}
	}
}

func TestHomepageJSONImageURLsCorrect(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/jsons/homepage.json")
	if err != nil {
		t.Fatalf("GET /jsons/homepage.json failed: %v", err)
	}
	defer resp.Body.Close()

	var data struct {
		Posts []struct {
			CardImage string `json:"card_image_url"`
			CardAVIF  string `json:"card_image_url_avif"`
			TopPhotos []struct {
				URL  string `json:"url"`
				AVIF string `json:"avif"`
			} `json:"top_photos"`
		} `json:"posts"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		t.Fatalf("JSON decode failed: %v", err)
	}

	for i, post := range data.Posts {
		// Card image URL must follow Crystal format: {slug}_{filename_without_ext}_{size}.{format}
		if post.CardImage != "" {
			// Must NOT have double extension (e.g. .jpg_card.jpg)
			if strings.Contains(post.CardImage, ".jpg_") || strings.Contains(post.CardImage, ".png_") {
				t.Errorf("post[%d] card_image_url has double extension: %s", i, post.CardImage)
			}
			// Must end with _card.jpg
			if !strings.HasSuffix(post.CardImage, "_card.jpg") {
				t.Errorf("post[%d] card_image_url should end with _card.jpg: %s", i, post.CardImage)
			}
			// Must start with /images/processed/
			if !strings.HasPrefix(post.CardImage, "/images/processed/") {
				t.Errorf("post[%d] card_image_url missing /images/processed/ prefix: %s", i, post.CardImage)
			}
		}
		if post.CardAVIF != "" {
			if !strings.HasSuffix(post.CardAVIF, "_card.avif") {
				t.Errorf("post[%d] card_image_url_avif should end with _card.avif: %s", i, post.CardAVIF)
			}
		}
		for j, photo := range post.TopPhotos {
			if strings.Contains(photo.URL, ".jpg_") || strings.Contains(photo.URL, ".png_") {
				t.Errorf("post[%d] top_photos[%d].url has double extension: %s", i, j, photo.URL)
			}
		}
	}
}

func TestHomepageStatsNotZero(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/index.html")
	defer page.MustClose()

	bikeText, _ := jsEval(page, `() => { var el = document.querySelector('.stat:nth-child(1) .stat-value'); return el ? el.textContent : '0'; }`)
	hikeText, _ := jsEval(page, `() => { var el = document.querySelector('.stat:nth-child(2) .stat-value'); return el ? el.textContent : '0'; }`)
	timeText, _ := jsEval(page, `() => { var el = document.querySelector('.stat:nth-child(3) .stat-value'); return el ? el.textContent : '0'; }`)

	bikeKm := parseIntFromText(bikeText)
	hikeKm := parseIntFromText(hikeText)
	hours := parseIntFromText(timeText)

	t.Logf("Stats: bike=%dkm, hike=%dkm, time=%dh", bikeKm, hikeKm, hours)

	if bikeKm+hikeKm == 0 {
		t.Error("total distance (bike + hike) should be > 0")
	}
	if hours == 0 {
		t.Error("time spent should be > 0")
	}
}

func TestHomepageHeroLoads(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/index.html")
	defer page.MustClose()

	// Wait for JS to remove hero-loading class
	err := waitForJS(page, `() => !document.querySelector('.hero-image.hero-loading')`, 10*time.Second)
	if err != nil {
		t.Fatal("hero image never finished loading")
	}

	// Check hero image has src
	src, _ := jsEval(page, `() => { var el = document.querySelector('.hero-image img'); return el ? (el.getAttribute('src') || '') : ''; }`)
	if src == "" {
		t.Error("hero image has no src")
	}

	// Check caption has content
	caption, _ := jsEval(page, `() => { var el = document.querySelector('.hero-image-caption h3'); return el ? el.textContent : ''; }`)
	if caption == "" {
		t.Error("hero caption is empty")
	}
}

func TestHomepagePostsGrid(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/index.html")
	defer page.MustClose()

	// Wait for post cards
	err := waitForJS(page, `() => document.querySelectorAll('.post-card').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no post cards rendered")
	}

	count, _ := jsEvalInt(page, `() => document.querySelectorAll('.post-card').length`)
	t.Logf("Post cards: %d", count)

	// First card should have an image
	src, _ := jsEval(page, `() => { var el = document.querySelector('.post-card .post-card-image img'); return el ? (el.getAttribute('src') || '') : ''; }`)
	if src == "" {
		t.Error("first card image has no src")
	}

	// First card should have a title
	title, _ := jsEval(page, `() => { var el = document.querySelector('.post-card .post-card-title'); return el ? el.textContent : ''; }`)
	if title == "" {
		t.Error("first card has empty title")
	}
}

func TestHomepageCategoryChips(t *testing.T) {
	ts := setupServer(t)
	page := ts.newPage(t, "/index.html")
	defer page.MustClose()

	// Wait for chips
	err := waitForJS(page, `() => document.querySelectorAll('.category-chip').length > 0`, 10*time.Second)
	if err != nil {
		t.Fatal("no category chips rendered")
	}

	count, _ := jsEvalInt(page, `() => document.querySelectorAll('.category-chip').length`)
	t.Logf("Category chips: %d", count)

	// First chip should have href
	href, _ := jsEval(page, `() => { var el = document.querySelector('.category-chip'); return el ? (el.getAttribute('href') || '') : ''; }`)
	if href == "" {
		t.Error("first chip has no href")
	}
}

// parseIntFromText extracts the first integer from a string like "123km" or "45h".
func parseIntFromText(s string) int {
	s = strings.TrimSpace(s)
	numStr := ""
	for _, c := range s {
		if c >= '0' && c <= '9' {
			numStr += string(c)
		} else if numStr != "" {
			break
		}
	}
	n, _ := strconv.Atoi(numStr)
	return n
}
