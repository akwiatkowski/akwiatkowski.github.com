package view

import (
	"bytes"
	"fmt"
	"os"
	"time"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/renderer/html"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// AboutPage creates a Renderable for the "O mnie" page.
func AboutPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver, pagesDir string) Renderable {
	url := rtr.AboutURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	content := renderMarkdownFile(pagesDir, "about.md")

	page := layout.PageData{
		Title:        "O mnie",
		Desc:         "O mnie i o tej stronie",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.StaticAboutContent(content), true)
}

// EnglishPage creates a Renderable for the English about page.
func EnglishPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver, pagesDir string) Renderable {
	url := rtr.EnglishURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	content := renderMarkdownFile(pagesDir, "en.md")

	page := layout.PageData{
		Title:        "Welcome",
		Desc:         "A few words for English only speaking visitors",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.StaticEnglishContent(content), true)
}

// MorePage creates a Renderable for the "Więcej" page.
func MorePage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	url := rtr.MoreURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	currentYear := time.Now().Year()

	links := []views.MoreLink{
		{URL: rtr.PortfolioURL(), Name: "Portfolio", Desc: "Wybrane najlepsze zdjęcia z wycieczek", Icon: "portfolio"},
		{URL: rtr.YearReportURL(currentYear), Name: fmt.Sprintf("Rok %d", currentYear), Desc: fmt.Sprintf("Podsumowanie roku %d — trasy, kilometry, zdjęcia", currentYear), Icon: "calendar"},
		{URL: rtr.PhotoMapURL(), Name: "Mapa zdjęć", Desc: "Przeglądaj zdjęcia na mapie w stylu Panoramio", Icon: "photos"},
		{URL: rtr.TimelineURL(), Name: "Linia czasu", Desc: "Zdjęcia ułożone według miesiąca i dnia roku", Icon: "clock"},
		{URL: rtr.MapURL(), Name: "Mapa tras", Desc: "Interaktywna mapa z trasami wycieczek", Icon: "map"},
		{URL: rtr.TripIdeasURL(), Name: "Pomysły na trasy", Desc: "Planer rowerowych wycieczek z filtrami i mapami", Icon: "idea"},
		{URL: rtr.PhotoPlannerURL(), Name: "Planer dla zdjęć", Desc: "Generator tras optymalizujący pokrycie zdjęciami", Icon: "camera"},
		{URL: rtr.ExifStatsURL(), Name: "Statystyki EXIF", Desc: "Wykresy i heatmapy z metadanych zdjęć", Icon: "stats"},
	}

	page := layout.PageData{
		Title:        "Więcej",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.StaticMoreContent(links), true)
}

// renderMarkdownFile reads a markdown file and renders it to HTML.
// Returns empty string if file not found or on error.
func renderMarkdownFile(dir, filename string) string {
	path := dir + "/" + filename
	src, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	md := goldmark.New(goldmark.WithRendererOptions(html.WithUnsafe()))
	var buf bytes.Buffer
	if err := md.Convert(src, &buf); err != nil {
		return ""
	}
	return buf.String()
}
