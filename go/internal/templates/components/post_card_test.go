package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestPostCard_RendersLinkWithTitle(t *testing.T) {
	card := components.PostCardData{
		URL:   "/2023/06/15-wycieczka.html",
		Title: "Wycieczka rowerowa",
	}
	out := h.Render(t, components.PostCard(card))
	doc := h.Parse(t, out)

	links := h.FindByClass(doc, "post-card")
	if len(links) == 0 {
		t.Fatal("expected .post-card link")
	}
	if href := h.AttrVal(links[0], "href"); href != "/2023/06/15-wycieczka.html" {
		t.Errorf("expected href, got %q", href)
	}

	h3s := h.FindByTag(links[0], "h3")
	if len(h3s) == 0 {
		t.Fatal("expected <h3> with title")
	}
	if text := h.InnerText(h3s[0]); text != "Wycieczka rowerowa" {
		t.Errorf("expected title text, got %q", text)
	}
}

func TestPostCard_RendersSubtitle(t *testing.T) {
	card := components.PostCardData{
		URL:      "/post.html",
		Title:    "Title",
		Subtitle: "A nice day out",
	}
	out := h.Render(t, components.PostCard(card))
	doc := h.Parse(t, out)

	subs := h.FindByClass(doc, "subtitle")
	if len(subs) == 0 {
		t.Fatal("expected .subtitle element")
	}
	if text := h.InnerText(subs[0]); text != "A nice day out" {
		t.Errorf("expected subtitle text, got %q", text)
	}
}

func TestPostCard_OmitsSubtitleWhenEmpty(t *testing.T) {
	card := components.PostCardData{
		URL:   "/post.html",
		Title: "Title",
	}
	out := h.Render(t, components.PostCard(card))
	h.AssertNotContains(t, out, "subtitle")
}

func TestPostCard_RendersPhoto(t *testing.T) {
	photo := &components.PhotoCardData{
		JPEGSrc: "/thumb.jpg",
		AVIFSrc: "/thumb.avif",
		Alt:     "Thumb",
	}
	card := components.PostCardData{
		URL:   "/post.html",
		Title: "With Photo",
		Photo: photo,
	}
	out := h.Render(t, components.PostCard(card))
	doc := h.Parse(t, out)

	cards := h.FindByClass(doc, "photo-card")
	if len(cards) == 0 {
		t.Error("expected photo-card within post-card")
	}
}

func TestPostCard_RendersStats(t *testing.T) {
	stats := &components.PostStatsData{
		Distance:  25,
		TimeSpent: 3,
		Elevation: 200,
	}
	card := components.PostCardData{
		URL:   "/post.html",
		Title: "With Stats",
		Stats: stats,
	}
	out := h.Render(t, components.PostCard(card))
	doc := h.Parse(t, out)

	postStats := h.FindByClass(doc, "post-stats")
	if len(postStats) == 0 {
		t.Error("expected .post-stats within post-card")
	}
}

func TestPostCard_OmitsPhotoAndStatsWhenNil(t *testing.T) {
	card := components.PostCardData{
		URL:   "/post.html",
		Title: "Minimal",
	}
	out := h.Render(t, components.PostCard(card))
	h.AssertNotContains(t, out, "photo-card")
	h.AssertNotContains(t, out, "post-stats")
}
