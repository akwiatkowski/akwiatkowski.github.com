package layout_test

import (
	"strings"
	"testing"

	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/view/template/htmltest"
	"odkrywajac/internal/view/template/layout"
)

func samplePageData() layout.PageData {
	return layout.PageData{
		Title:        "Test Page",
		Desc:         "A test description",
		CanonicalURL: "https://example.com/test.html",
		ImageURL:     "https://example.com/og.jpg",
		SiteName:     "Odkrywając Polskę",
		CSSFiles: []bundle.AssetFile{
			{Path: "/css/style.css", Integrity: "sha256-abc123", IsCSS: true, Version: "100"},
		},
		JSFiles: []bundle.AssetFile{
			{Path: "/js/app.js", IsCSS: false, Version: "200"},
		},
		PageJSFiles: []string{"/js/self/page.js"},
		NavStats: layout.NavStats{
			BicycleDistance: 1234,
			HikeDistance:    567,
			SelfTime:        89,
			Links: layout.NavLinks{
				RoweremURL:   "/wpisy-dla/tagu/rowerem.html",
				PieszoURL:    "/wpisy-dla/tagu/pieszo.html",
				NajlepszeURL: "/wpisy-dla/tagu/najlepsze.html",
				MapURL:       "/mapa_tras.html",
			},
		},
	}
}

// --- Head ---

func TestHead_RendersTitle(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.Head(pd))
	htmltest.AssertContains(t, out, "Test Page - Odkrywając Polskę")
}

func TestHead_RendersTitleFallback(t *testing.T) {
	pd := samplePageData()
	pd.Title = ""
	out := htmltest.Render(t, layout.Head(pd))
	doc := htmltest.Parse(t, out)
	titles := htmltest.FindByTag(doc, "title")
	if len(titles) == 0 {
		t.Fatal("expected <title>")
	}
	text := htmltest.InnerText(titles[0])
	if text != "Odkrywając Polskę" {
		t.Errorf("expected site name as title, got %q", text)
	}
}

func TestHead_RendersCanonicalURL(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.Head(pd))
	doc := htmltest.Parse(t, out)

	links := htmltest.FindAll(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "link") && htmltest.HasAttr(n, "rel", "canonical")
	})
	if len(links) == 0 {
		t.Fatal("expected canonical link")
	}
	if href := htmltest.AttrVal(links[0], "href"); href != "https://example.com/test.html" {
		t.Errorf("expected canonical href, got %q", href)
	}
}

func TestHead_RendersMetaDescription(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.Head(pd))
	doc := htmltest.Parse(t, out)

	metas := htmltest.FindAll(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "name", "description")
	})
	if len(metas) == 0 {
		t.Fatal("expected meta description")
	}
	if content := htmltest.AttrVal(metas[0], "content"); content != "A test description" {
		t.Errorf("expected description content, got %q", content)
	}
}

func TestHead_OmitsDescWhenEmpty(t *testing.T) {
	pd := samplePageData()
	pd.Desc = ""
	out := htmltest.Render(t, layout.Head(pd))
	doc := htmltest.Parse(t, out)

	metas := htmltest.FindAll(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "name", "description")
	})
	if len(metas) != 0 {
		t.Error("expected no meta description when Desc is empty")
	}
}

// Fonts are self-hosted (/css/self/fonts.css via the core bundle) — the head
// must not reach out to Google Fonts.
func TestHead_NoGoogleFonts(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.Head(pd))
	if strings.Contains(out, "fonts.googleapis.com") || strings.Contains(out, "fonts.gstatic.com") {
		t.Error("head must not reference Google Fonts (fonts are self-hosted)")
	}
}

// --- HeadOG ---

func TestHeadOG_RendersOGTags(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.HeadOG(pd))
	doc := htmltest.Parse(t, out)

	ogType := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "property", "og:type")
	})
	if ogType == nil {
		t.Fatal("expected og:type meta")
	}
	if htmltest.AttrVal(ogType, "content") != "website" {
		t.Error("expected og:type = website")
	}

	ogTitle := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "property", "og:title")
	})
	if ogTitle == nil {
		t.Fatal("expected og:title")
	}
	if htmltest.AttrVal(ogTitle, "content") != "Test Page" {
		t.Errorf("expected og:title 'Test Page', got %q", htmltest.AttrVal(ogTitle, "content"))
	}

	ogImage := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "property", "og:image")
	})
	if ogImage == nil {
		t.Fatal("expected og:image")
	}
	if htmltest.AttrVal(ogImage, "content") != "https://example.com/og.jpg" {
		t.Error("expected og:image URL")
	}

	twitterCard := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "name", "twitter:card")
	})
	if twitterCard == nil {
		t.Fatal("expected twitter:card meta")
	}
	if htmltest.AttrVal(twitterCard, "content") != "summary_large_image" {
		t.Error("expected twitter:card summary_large_image")
	}
}

func TestHeadOG_OmitsEmptyFields(t *testing.T) {
	pd := layout.PageData{} // all empty
	out := htmltest.Render(t, layout.HeadOG(pd))
	doc := htmltest.Parse(t, out)

	ogTitle := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "property", "og:title")
	})
	if ogTitle != nil {
		t.Error("expected no og:title when Title is empty")
	}

	ogImage := htmltest.FindOne(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "meta") && htmltest.HasAttr(n, "property", "og:image")
	})
	if ogImage != nil {
		t.Error("expected no og:image when ImageURL is empty")
	}
}

// --- HeadAssets ---

func TestHeadAssets_RendersCSSWithIntegrity(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.HeadAssets(pd))
	doc := htmltest.Parse(t, out)

	stylesheets := htmltest.FindAll(doc, func(n *htmltest.Node) bool {
		return htmltest.IsElement(n, "link") && htmltest.HasAttr(n, "rel", "stylesheet")
	})
	if len(stylesheets) == 0 {
		t.Fatal("expected stylesheet link")
	}
	href := htmltest.AttrVal(stylesheets[0], "href")
	if href != "/css/style.css?v=100" {
		t.Errorf("expected versioned CSS path, got %q", href)
	}
	if integrity := htmltest.AttrVal(stylesheets[0], "integrity"); integrity != "sha256-abc123" {
		t.Errorf("expected integrity hash, got %q", integrity)
	}
	if crossorigin := htmltest.AttrVal(stylesheets[0], "crossorigin"); crossorigin != "anonymous" {
		t.Errorf("expected crossorigin anonymous, got %q", crossorigin)
	}
}

func TestHeadAssets_RendersJSScript(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.HeadAssets(pd))
	doc := htmltest.Parse(t, out)

	scripts := htmltest.FindByTag(doc, "script")
	if len(scripts) == 0 {
		t.Fatal("expected script tags")
	}

	// Find the app.js script (not the page.js)
	found := false
	for _, script := range scripts {
		src := htmltest.AttrVal(script, "src")
		if src == "/js/app.js?v=200" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected script with versioned app.js path")
	}
}

func TestHeadAssets_RendersPageJS(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.HeadAssets(pd))
	htmltest.AssertContains(t, out, `/js/self/page.js`)
	htmltest.AssertContains(t, out, "defer")
}

func TestHeadAssets_OmitsPageJSWhenEmpty(t *testing.T) {
	pd := samplePageData()
	pd.PageJSFiles = nil
	out := htmltest.Render(t, layout.HeadAssets(pd))
	htmltest.AssertNotContains(t, out, "defer")
}

// --- Nav ---

func TestNav_RendersLogo(t *testing.T) {
	stats := samplePageData().NavStats
	out := htmltest.Render(t, layout.Nav(stats))
	doc := htmltest.Parse(t, out)

	logos := htmltest.FindByClass(doc, "nav-logo")
	if len(logos) == 0 {
		t.Fatal("expected .nav-logo")
	}
	if text := htmltest.InnerText(logos[0]); text != "Odkrywając Polskę" {
		t.Errorf("expected logo text, got %q", text)
	}
	if href := htmltest.AttrVal(logos[0], "href"); href != "/" {
		t.Errorf("expected logo href '/', got %q", href)
	}
}

func TestNav_RendersFourLinks(t *testing.T) {
	stats := samplePageData().NavStats
	out := htmltest.Render(t, layout.Nav(stats))
	doc := htmltest.Parse(t, out)

	navLinks := htmltest.FindByClass(doc, "nav-links")
	if len(navLinks) == 0 {
		t.Fatal("expected .nav-links")
	}

	lis := htmltest.FindByTag(navLinks[0], "li")
	if len(lis) != 4 {
		t.Errorf("expected 4 nav links, got %d", len(lis))
	}

	// Check link texts
	expectedTexts := []string{"Rowerem", "Pieszo", "Najlepsze", "Mapa"}
	for i, li := range lis {
		link := htmltest.FindOne(li, func(n *htmltest.Node) bool { return htmltest.IsElement(n, "a") })
		if link == nil {
			t.Errorf("expected link in li %d", i)
			continue
		}
		text := htmltest.InnerText(link)
		if text != expectedTexts[i] {
			t.Errorf("nav link %d: expected %q, got %q", i, expectedTexts[i], text)
		}
	}
}

func TestNav_RendersCorrectURLs(t *testing.T) {
	stats := samplePageData().NavStats
	out := htmltest.Render(t, layout.Nav(stats))
	htmltest.AssertContains(t, out, "/wpisy-dla/tagu/rowerem.html")
	htmltest.AssertContains(t, out, "/wpisy-dla/tagu/pieszo.html")
	htmltest.AssertContains(t, out, "/wpisy-dla/tagu/najlepsze.html")
	htmltest.AssertContains(t, out, "/mapa_tras.html")
}

// --- Footer ---

func TestFooter_RendersCopyright(t *testing.T) {
	out := htmltest.Render(t, layout.Footer())
	htmltest.AssertContains(t, out, "Aleksander Kwiatkowski")
}

func TestFooter_RendersLinks(t *testing.T) {
	out := htmltest.Render(t, layout.Footer())
	doc := htmltest.Parse(t, out)

	footerLinks := htmltest.FindByClass(doc, "footer-links")
	if len(footerLinks) == 0 {
		t.Fatal("expected .footer-links")
	}

	links := htmltest.FindByTag(footerLinks[0], "a")
	if len(links) != 3 {
		t.Errorf("expected 3 footer links, got %d", len(links))
	}

	expectedHrefs := []string{"/galeria.html", "/o-mnie.html", "/wiecej.html"}
	expectedTexts := []string{"Galeria", "O mnie", "Więcej"}
	for i, link := range links {
		if href := htmltest.AttrVal(link, "href"); href != expectedHrefs[i] {
			t.Errorf("footer link %d: expected href %q, got %q", i, expectedHrefs[i], href)
		}
		if text := htmltest.InnerText(link); text != expectedTexts[i] {
			t.Errorf("footer link %d: expected text %q, got %q", i, expectedTexts[i], text)
		}
	}
}

// --- Page ---

func TestPage_RendersFullHTMLStructure(t *testing.T) {
	pd := samplePageData()
	content := layout.Page(pd)
	out := htmltest.Render(t, content)

	htmltest.AssertContains(t, out, "<!doctype html>")
	htmltest.AssertContains(t, out, `<html lang="pl">`)

	doc := htmltest.Parse(t, out)

	heads := htmltest.FindByTag(doc, "head")
	if len(heads) == 0 {
		t.Error("expected <head>")
	}

	bodies := htmltest.FindByTag(doc, "body")
	if len(bodies) == 0 {
		t.Error("expected <body>")
	}

	// Nav should be inside body
	navs := htmltest.FindByTag(doc, "nav")
	if len(navs) == 0 {
		t.Error("expected <nav> inside body")
	}

	// Footer should be inside body
	footers := htmltest.FindByTag(doc, "footer")
	if len(footers) == 0 {
		t.Error("expected <footer> inside body")
	}
}

func TestPage_RendersHeadTitle(t *testing.T) {
	pd := samplePageData()
	out := htmltest.Render(t, layout.Page(pd))
	htmltest.AssertContains(t, out, "Test Page - Odkrywając Polskę")
}
