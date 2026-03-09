package view

import (
	"bytes"
	"strings"
	"testing"

	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

func TestTagPostListPageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	tag := data.TagBySlug["bicycle"]

	page := TagPostListPage(data, tag, r, nil)
	if page.URL() != "/wpisy-dla/tagu/rowerem.html" {
		t.Errorf("URL() = %q", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("tag post list should be in sitemap")
	}
}

func TestTagPostListPageRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	tag := data.TagBySlug["bicycle"]

	page := TagPostListPage(data, tag, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Wpisy: Rowerem",
		"post-collection-config",
		`"filterBy":"tag"`,
		`"filterValue":"bicycle"`, // English slug for JS filtering
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestTagGalleryPageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	tag := data.TagBySlug["bicycle"]

	page := TagGalleryPage(data, tag, r, nil)
	if page.URL() != "/galeria/tag/rowerem.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestCollectPhotosByTag(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")

	// Add photo entities with tags to a post
	post := data.PostBySlug("2021-07-18-pagorki")
	if post == nil {
		t.Fatal("post not found")
	}
	post.PublishedPhotos = []*model.Photo{
		{
			ImageFilename: "photo1.jpg",
			PostSlug:      "2021-07-18-pagorki",
			Desc:          "Photo 1",
			TagSlugs:      []string{"good", "best"},
		},
		{
			ImageFilename: "photo2.jpg",
			PostSlug:      "2021-07-18-pagorki",
			Desc:          "Photo 2",
			TagSlugs:      []string{"good"},
		},
	}

	cards := collectPhotosByTag(data, "good", r)
	if len(cards) != 2 {
		t.Errorf("expected 2 photos with 'good' tag, got %d", len(cards))
	}

	cards = collectPhotosByTag(data, "best", r)
	if len(cards) != 1 {
		t.Errorf("expected 1 photo with 'best' tag, got %d", len(cards))
	}
}
