package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestArticlePhoto_RendersCaption(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "Sunset over the lake",
	}
	out := h.Render(t, components.ArticlePhoto(data))
	doc := h.Parse(t, out)

	figcaption := h.FindByTag(doc, "figcaption")
	if len(figcaption) == 0 {
		t.Fatal("expected <figcaption> element")
	}
	text := h.InnerText(figcaption[0])
	if text == "" || !containsStr(text, "Sunset over the lake") {
		t.Errorf("figcaption should contain caption text, got: %q", text)
	}
}

func TestArticlePhoto_RendersPictureWithAVIF(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "Test",
	}
	out := h.Render(t, components.ArticlePhoto(data))
	doc := h.Parse(t, out)

	pictures := h.FindByTag(doc, "picture")
	if len(pictures) == 0 {
		t.Fatal("expected <picture> element")
	}

	sources := h.FindByTag(pictures[0], "source")
	if len(sources) == 0 {
		t.Fatal("expected <source> element for AVIF")
	}
	if typ := h.AttrVal(sources[0], "type"); typ != "image/avif" {
		t.Errorf("expected source type image/avif, got %q", typ)
	}

	imgs := h.FindByTag(pictures[0], "img")
	if len(imgs) == 0 {
		t.Fatal("expected <img> element")
	}
	if src := h.AttrVal(imgs[0], "src"); src != "/photos/article.jpg" {
		t.Errorf("expected img src /photos/article.jpg, got %q", src)
	}
	if alt := h.AttrVal(imgs[0], "alt"); alt != "Test" {
		t.Errorf("expected img alt 'Test', got %q", alt)
	}
}

func TestArticlePhoto_RendersGPSData(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "GPS test",
		HasGPS:      true,
		Lat:         52.123456,
		Lon:         16.654321,
		Altitude:    120.5,
	}
	out := h.Render(t, components.ArticlePhoto(data))
	doc := h.Parse(t, out)

	imgs := h.FindByTag(doc, "img")
	if len(imgs) == 0 {
		t.Fatal("expected <img>")
	}
	img := imgs[0]
	if lat := h.AttrVal(img, "data-lat"); lat != "52.123456" {
		t.Errorf("expected data-lat 52.123456, got %q", lat)
	}
	if lon := h.AttrVal(img, "data-lon"); lon != "16.654321" {
		t.Errorf("expected data-lon 16.654321, got %q", lon)
	}
}

func TestArticlePhoto_OmitsGPSWhenNotSet(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "No GPS",
		HasGPS:      false,
	}
	out := h.Render(t, components.ArticlePhoto(data))
	h.AssertNotContains(t, out, "data-lat")
	h.AssertNotContains(t, out, "data-lon")
}

func TestArticlePhoto_RendersExifString(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "EXIF test",
		ExifString:  "f/2.8 1/200s ISO400",
	}
	out := h.Render(t, components.ArticlePhoto(data))
	doc := h.Parse(t, out)

	exifSpans := h.FindByClass(doc, "photo-exif")
	if len(exifSpans) == 0 {
		t.Fatal("expected .photo-exif span")
	}
	text := h.InnerText(exifSpans[0])
	if text != "f/2.8 1/200s ISO400" {
		t.Errorf("expected exif text, got %q", text)
	}
}

func TestArticlePhoto_OmitsExifWhenEmpty(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "No EXIF",
		ExifString:  "",
	}
	out := h.Render(t, components.ArticlePhoto(data))
	h.AssertNotContains(t, out, "photo-exif")
}

func TestArticlePhoto_RendersTagLinks(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "Tagged",
		TagLinks: []components.PhotoTagLink{
			{URL: "/tag/best.html", Icon: "gem"},
			{URL: "/tag/nature.html", Icon: "flower2"},
		},
	}
	out := h.Render(t, components.ArticlePhoto(data))
	doc := h.Parse(t, out)

	captionSpan := h.FindByClass(doc, "photo-caption-title")
	if len(captionSpan) == 0 {
		t.Fatal("expected .photo-caption-title")
	}
	links := h.FindByTag(captionSpan[0], "a")
	if len(links) != 2 {
		t.Errorf("expected 2 tag links, got %d", len(links))
	}
}

func TestArticlePhoto_RendersTimeData(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "Time test",
		HasTime:     true,
		TimeStr:     "2023-06-15T10:30:00Z",
	}
	out := h.Render(t, components.ArticlePhoto(data))
	h.AssertContains(t, out, `data-time="2023-06-15T10:30:00Z"`)
}

func TestArticlePhoto_RendersGalleryFlags(t *testing.T) {
	data := components.ArticlePhotoData{
		FullSizeURL: "/photos/full.jpg",
		ArticleJPEG: "/photos/article.jpg",
		ArticleAVIF: "/photos/article.avif",
		GridJPEG:    "/photos/grid.jpg",
		GridAVIF:    "/photos/grid.avif",
		Caption:     "Flags",
		IsGallery:   true,
		IsTimeline:  false,
	}
	out := h.Render(t, components.ArticlePhoto(data))
	h.AssertContains(t, out, `data-is-gallery="true"`)
	h.AssertContains(t, out, `data-is-timeline="false"`)
}

func TestBootstrapIcon_RendersSVG(t *testing.T) {
	out := h.Render(t, components.BootstrapIcon("gem"))
	doc := h.Parse(t, out)

	svgs := h.FindByTag(doc, "svg")
	if len(svgs) == 0 {
		t.Fatal("expected <svg> element")
	}
	if !h.HasClass(svgs[0], "bi") {
		t.Error("expected svg to have class 'bi'")
	}

	uses := h.FindByTag(svgs[0], "use")
	if len(uses) == 0 {
		t.Fatal("expected <use> element")
	}
	href := h.AttrVal(uses[0], "href")
	if href != "/icons/bootstrap-icons.svg#gem" {
		t.Errorf("expected href /icons/bootstrap-icons.svg#gem, got %q", href)
	}
}

func TestResolveBootstrapIcon(t *testing.T) {
	if icon := components.ResolveBootstrapIcon("best"); icon != "gem" {
		t.Errorf("expected gem for best, got %q", icon)
	}
	if icon := components.ResolveBootstrapIcon("cat"); icon != "eye-fill" {
		t.Errorf("expected eye-fill for cat, got %q", icon)
	}
	if icon := components.ResolveBootstrapIcon("unknown_tag"); icon != "" {
		t.Errorf("expected empty for unknown tag, got %q", icon)
	}
}

func containsStr(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && stringContains(s, substr))
}

func stringContains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
