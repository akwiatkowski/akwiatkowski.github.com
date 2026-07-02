package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestRedirectPage_RendersMetaRefresh(t *testing.T) {
	out := h.Render(t, components.RedirectPage("/wpisy-dla/tagu/rowerem.html", 302))
	h.AssertContains(t, out, `content="0; url=/wpisy-dla/tagu/rowerem.html"`)
}

func TestRedirectPage_RendersTitle(t *testing.T) {
	out := h.Render(t, components.RedirectPage("/target.html", 302))
	doc := h.Parse(t, out)

	titles := h.FindByTag(doc, "title")
	if len(titles) == 0 {
		t.Fatal("expected <title>")
	}
	text := h.InnerText(titles[0])
	if text != "Redirect (302)" {
		t.Errorf("expected 'Redirect (302)', got %q", text)
	}
}

func TestRedirectPage_RendersLinkToTarget(t *testing.T) {
	out := h.Render(t, components.RedirectPage("/new-page.html", 301))
	doc := h.Parse(t, out)

	links := h.FindByTag(doc, "a")
	found := false
	for _, link := range links {
		if h.AttrVal(link, "href") == "/new-page.html" {
			found = true
			text := h.InnerText(link)
			if text != "/new-page.html" {
				t.Errorf("expected link text to be target URL, got %q", text)
			}
			break
		}
	}
	if !found {
		t.Error("expected link with href to target")
	}
}

func TestRedirectPage_RendersRedirectScript(t *testing.T) {
	out := h.Render(t, components.RedirectPage("/target.html", 302))
	h.AssertContains(t, out, "<script")
	h.AssertContains(t, out, "window.location.replace")
}

func TestRedirectPage_IsFullHTML(t *testing.T) {
	out := h.Render(t, components.RedirectPage("/target.html", 302))
	h.AssertContains(t, out, "<!doctype html>")
	h.AssertContains(t, out, `<html lang="pl">`)
	h.AssertContains(t, out, "<head>")
	h.AssertContains(t, out, "<body>")
}
