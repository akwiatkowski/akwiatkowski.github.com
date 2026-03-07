package view

import (
	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// PortfolioPage creates a Renderable for the photo portfolio page.
// It displays photos tagged as "best".
func PortfolioPage(
	data *index.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := rtr.PortfolioURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"gallery"})

	page := layout.PageData{
		Title:        "Portfolio",
		Desc:         "Wybrane najlepsze zdjęcia z wycieczek",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats),
	}

	// Collect "best" tagged photos
	photoCards := collectPhotosByTag(data, "best", rtr)

	return NewHTMLPage(url, page, views.AreaGalleryContent(photoCards), true)
}
