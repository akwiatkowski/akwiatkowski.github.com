package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestPhotoCard_RendersWithAVIF(t *testing.T) {
	photo := components.PhotoCardData{
		JPEGSrc: "/photos/grid.jpg",
		AVIFSrc: "/photos/grid.avif",
		Alt:     "Mountain view",
		Width:   "560",
		Height:  "420",
	}
	out := h.Render(t, components.PhotoCard(photo))
	doc := h.Parse(t, out)

	pictures := h.FindByClass(doc, "photo-card")
	if len(pictures) == 0 {
		t.Fatal("expected .photo-card picture element")
	}

	sources := h.FindByTag(pictures[0], "source")
	if len(sources) == 0 {
		t.Fatal("expected <source> for AVIF")
	}
	if srcset := h.AttrVal(sources[0], "srcset"); srcset != "/photos/grid.avif" {
		t.Errorf("expected AVIF srcset, got %q", srcset)
	}
	if typ := h.AttrVal(sources[0], "type"); typ != "image/avif" {
		t.Errorf("expected type image/avif, got %q", typ)
	}

	imgs := h.FindByTag(pictures[0], "img")
	if len(imgs) == 0 {
		t.Fatal("expected <img>")
	}
	img := imgs[0]
	if h.AttrVal(img, "src") != "/photos/grid.jpg" {
		t.Errorf("expected JPEG src")
	}
	if h.AttrVal(img, "alt") != "Mountain view" {
		t.Errorf("expected alt 'Mountain view'")
	}
	if h.AttrVal(img, "width") != "560" {
		t.Errorf("expected width 560")
	}
	if h.AttrVal(img, "loading") != "lazy" {
		t.Error("expected loading=lazy")
	}
}

func TestPhotoCard_OmitsAVIFWhenEmpty(t *testing.T) {
	photo := components.PhotoCardData{
		JPEGSrc: "/photos/grid.jpg",
		Alt:     "No AVIF",
	}
	out := h.Render(t, components.PhotoCard(photo))
	h.AssertNotContains(t, out, "image/avif")
	h.AssertNotContains(t, out, "<source")
}

func TestPhotoCard_OmitsDimensionsWhenEmpty(t *testing.T) {
	photo := components.PhotoCardData{
		JPEGSrc: "/photos/grid.jpg",
		Alt:     "No dims",
	}
	out := h.Render(t, components.PhotoCard(photo))
	h.AssertNotContains(t, out, "width=")
	h.AssertNotContains(t, out, "height=")
}

func TestPhotoGrid_RendersCorrectColumns(t *testing.T) {
	photos := []components.PhotoCardData{
		{JPEGSrc: "/1.jpg", Alt: "one"},
		{JPEGSrc: "/2.jpg", Alt: "two"},
		{JPEGSrc: "/3.jpg", Alt: "three"},
	}
	out := h.Render(t, components.PhotoGrid(photos, 3))
	doc := h.Parse(t, out)

	grids := h.FindByClass(doc, "photo-grid")
	if len(grids) == 0 {
		t.Fatal("expected .photo-grid")
	}
	if !h.HasClass(grids[0], "cols-3") {
		t.Error("expected cols-3 class")
	}

	cards := h.FindByClass(grids[0], "photo-card")
	if len(cards) != 3 {
		t.Errorf("expected 3 photo cards, got %d", len(cards))
	}
}

func TestPhotoGrid_EmptyPhotos(t *testing.T) {
	out := h.Render(t, components.PhotoGrid(nil, 3))
	doc := h.Parse(t, out)

	cards := h.FindByClass(doc, "photo-card")
	if len(cards) != 0 {
		t.Errorf("expected 0 photo cards for empty input, got %d", len(cards))
	}
}
