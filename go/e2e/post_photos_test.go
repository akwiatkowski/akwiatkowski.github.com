package e2e

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

// TestPostArticleHasPhotos verifies that a rendered post page contains
// inline photo elements from the markdown {% photo %} directives.
func TestPostArticleHasPhotos(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/2022/12/18-zdazyc-przed-koncem-zimy.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	// Article should contain photo containers from markdown rendering.
	photoCount := strings.Count(html, "post-article-photo")
	if photoCount == 0 {
		t.Error("post page has no article photos")
	}
	t.Logf("Found %d photo elements", photoCount)

	// Photos should have <picture> elements with AVIF and JPEG sources.
	if !strings.Contains(html, "<picture") {
		t.Error("post page has no <picture> elements")
	}
	if !strings.Contains(html, "image/avif") {
		t.Error("post page missing AVIF source in <picture>")
	}

	// Photos should link to full-size images.
	if !strings.Contains(html, "/images/") {
		t.Error("post page missing /images/ links for full-size photos")
	}
}

// TestPostArticlePhotoHasCaption verifies photo captions are rendered.
func TestPostArticlePhotoHasCaption(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/2022/12/18-zdazyc-przed-koncem-zimy.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	// At least some photos should have captions.
	if !strings.Contains(html, "photo-caption-title") {
		t.Error("no photo captions found in post page")
	}
}

// TestPostGalleryJSONHasPhotos verifies the gallery JSON for a post has photo entries.
func TestPostGalleryJSONHasPhotos(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/galeria/2022/12/18-zdazyc-przed-koncem-zimy.html")
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	// Gallery page should contain JSON config with photo data.
	if !strings.Contains(html, "gallery-config") {
		t.Error("gallery page missing gallery-config script")
	}
	if !strings.Contains(html, "article") {
		t.Error("gallery page should reference article-size images")
	}
}
