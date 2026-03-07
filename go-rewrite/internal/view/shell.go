package view

import (
	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// ShellPage creates a Renderable for a JS-heavy shell page.
// These pages have a <div id="root"> container and page-specific JS that runs client-side.
func ShellPage(
	data *index.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
	url, title string,
	bundles []string,
	pageAssets []string,
	pageJS string,
) Renderable {
	cssFiles, jsFiles := resolveAssets(resolver, bundles, pageAssets)

	page := layout.PageData{
		Title:        title,
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJS:       pageJS,
		NavStats:     navStatsFromIndex(data.NavStats),
	}

	return NewHTMLPage(url, page, views.ShellContent(), true)
}

// RouteMapPage creates the route map shell page.
func RouteMapPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.MapURL(), "Mapa tras",
		[]string{"core", "leaflet"}, []string{"map"},
		"/js/self/map.js",
	)
}

// PhotoMapPage creates the photo map shell page.
func PhotoMapPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.PhotoMapURL(), "Mapa zdjęć",
		[]string{"core", "leaflet", "react-runtime"}, nil,
		"/js/self/photo_map.js",
	)
}

// TimelinePage creates the timeline shell page.
func TimelinePage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.TimelineURL(), "Linia czasu",
		[]string{"core", "leaflet", "timeline-js"}, []string{"timeline"},
		"/js/self/timeline.js",
	)
}

// ExifStatsPage creates the EXIF statistics shell page.
func ExifStatsPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.ExifStatsURL(), "Statystyki EXIF",
		[]string{"core"}, []string{"exif_stats"},
		"/js/self/exif_stats.js",
	)
}

// PhotoPlannerPage creates the photo planner shell page.
func PhotoPlannerPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.PhotoPlannerURL(), "Planer dla zdjęć",
		[]string{"core", "leaflet"}, []string{"planner"},
		"/js/self/photo_planner.js",
	)
}

// TripIdeasPage creates the trip ideas shell page.
func TripIdeasPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return ShellPage(data, rtr, resolver,
		rtr.TripIdeasURL(), "Pomysły na trasy",
		[]string{"core", "leaflet", "react-runtime"}, []string{"ideas"},
		"/js/self/trip_ideas.js",
	)
}
