package view

import (
	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

// GenerateAllViews collects all Renderables from the site data.
// All views are independent since SiteData is frozen/immutable.
func GenerateAllViews(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	polygonDir string,
) []Renderable {
	var all []Renderable

	// Area pages: show, post list, gallery for each area with posts
	for _, areaType := range model.AllAreaTypes() {
		areas := data.AreasWithPosts[areaType]
		for _, area := range areas {
			all = append(all,
				AreaShowPage(data, area, r, resolver, polygonDir),
				AreaPostListPage(data, area, r, resolver),
				AreaGalleryPage(data, area, r, resolver),
			)
		}
	}

	// JSON endpoints
	all = append(all, E2EJSON(data, r))

	// Tag redirects: /tag/<slug_pl>.html → /wpisy-dla/tagu/<slug_pl>.html
	for _, tag := range data.Tags {
		all = append(all, NewRedirectPage(
			r.TagShowURL(&tag),
			r.TagPostListURL(&tag),
			302,
		))
	}

	return all
}
