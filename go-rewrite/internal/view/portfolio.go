package view

import (
	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
)

// PortfolioPage creates a Renderable for the photo portfolio page.
// It displays photos tagged as "best" using the dynamic JS gallery with lightbox.
func PortfolioPage(
	data *index.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := rtr.PortfolioURL()
	allPhotos := allPublishedPhotos(data)
	photos := photosForTag(allPhotos, "best")
	return galleryPage(data, rtr, resolver, url, "Portfolio", photos)
}
