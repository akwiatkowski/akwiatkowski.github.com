package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestGeoLinks_RendersOSMLink(t *testing.T) {
	out := h.Render(t, components.GeoLinks(52.4, 16.9))
	doc := h.Parse(t, out)

	links := h.FindByTag(doc, "a")
	if len(links) < 1 {
		t.Fatal("expected at least 1 link")
	}
	osmHref := h.AttrVal(links[0], "href")
	if osmHref == "" {
		t.Fatal("expected OSM link href")
	}
	h.AssertContains(t, osmHref, "openstreetmap.org")
	h.AssertContains(t, osmHref, "52.4")
	h.AssertContains(t, osmHref, "16.9")

	if target := h.AttrVal(links[0], "target"); target != "_blank" {
		t.Errorf("expected target _blank, got %q", target)
	}
}

func TestGeoLinks_RendersGoogleMapsLink(t *testing.T) {
	out := h.Render(t, components.GeoLinks(52.4, 16.9))
	doc := h.Parse(t, out)

	links := h.FindByTag(doc, "a")
	if len(links) < 2 {
		t.Fatal("expected at least 2 links")
	}
	googleHref := h.AttrVal(links[1], "href")
	h.AssertContains(t, googleHref, "google.com/maps")
	h.AssertContains(t, googleHref, "52.4")
	h.AssertContains(t, googleHref, "16.9")
}

func TestGeoLinks_RendersMapIcons(t *testing.T) {
	out := h.Render(t, components.GeoLinks(52.4, 16.9))
	doc := h.Parse(t, out)

	imgs := h.FindByTag(doc, "img")
	if len(imgs) < 2 {
		t.Fatal("expected 2 map icons")
	}
	if src := h.AttrVal(imgs[0], "src"); src != "/img/osm.ico" {
		t.Errorf("expected OSM icon, got %q", src)
	}
	if src := h.AttrVal(imgs[1], "src"); src != "/img/google_maps.ico" {
		t.Errorf("expected Google Maps icon, got %q", src)
	}
}

func TestGeoLinks_HasGeoLinksClass(t *testing.T) {
	out := h.Render(t, components.GeoLinks(52.4, 16.9))
	doc := h.Parse(t, out)

	spans := h.FindByClass(doc, "geo-links")
	if len(spans) == 0 {
		t.Error("expected .geo-links wrapper")
	}
}
