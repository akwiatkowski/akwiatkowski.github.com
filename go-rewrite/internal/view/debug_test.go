package view

import (
	"bytes"
	"strings"
	"testing"

	"odkrywajac/internal/router"
)

func TestTagStatsPageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	rtr := router.New("https://example.com")

	page := TagStatsPage(data, rtr, nil)
	if page.URL() != "/debug/tagged_photos.html" {
		t.Errorf("got URL %q, want /debug/tagged_photos.html", page.URL())
	}
}

func TestTagStatsPageRenders(t *testing.T) {
	data := testSiteDataWithPosts()
	rtr := router.New("https://example.com")

	page := TagStatsPage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	output := buf.String()

	if !strings.Contains(output, "Photo Tag Stats") {
		t.Error("output should contain page title")
	}
	if !strings.Contains(output, "<table") {
		t.Error("output should contain table element")
	}
}

func TestTagStatsPageCountsPhotos(t *testing.T) {
	data := testSiteDataWithPosts()
	rtr := router.New("https://example.com")

	rows := buildTagStats(data, rtr)
	if len(rows) == 0 {
		t.Fatal("should have at least one row")
	}

	// testSiteDataWithPosts has posts with photos
	for _, row := range rows {
		if row.PostTitle == "" {
			t.Error("row should have post title")
		}
	}
}
