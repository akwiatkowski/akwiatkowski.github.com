package view

import (
	"github.com/a-h/templ"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// shellPage creates a Renderable for a JS-heavy shell page with custom content.
// The content component provides the HTML structure that the page-specific JS expects.
func shellPage(
	data *index.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
	url, title string,
	bundles []string,
	pageAssets []string,
	pageJS string,
	content templ.Component,
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
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	return NewHTMLPage(url, page, content, true)
}

// RouteMapPage creates the route map page with Leaflet map structure.
// The JS (map_leaflet.js) expects #map-container > #content for the Leaflet map.
func RouteMapPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.MapURL(), "Mapa tras",
		[]string{"core", "leaflet"}, []string{"map"},
		"/js/self/map_leaflet.js",
		views.ShellMapContent(),
	)
}

// PhotoMapPage creates the photo map shell page.
// Uses Preact with <div id="root"> — self-rendering JS component.
func PhotoMapPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.PhotoMapURL(), "Mapa zdjęć",
		[]string{"core", "leaflet", "react-runtime"}, []string{"photo_map"},
		"/js/self/photo_map.js",
		views.ShellContent(),
	)
}

// TimelinePage creates the timeline page with photo grid and slider.
// The JS (timeline.js) expects #photoGrid, #daySlider, modal elements, etc.
func TimelinePage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.TimelineURL(), "Linia czasu",
		[]string{"core", "leaflet"}, []string{"timeline"},
		"/js/self/timeline.js",
		views.ShellTimelineContent(),
	)
}

// ExifStatsPage creates the EXIF statistics page with Chart.js charts.
// The JS (exif_stats.js) expects 21+ <canvas> elements and filter controls.
func ExifStatsPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.ExifStatsURL(), "Statystyki EXIF",
		[]string{"core", "chartjs"}, []string{"exif_stats"},
		"/js/self/exif_stats.js",
		views.ShellExifStatsContent(),
	)
}

// PhotoPlannerPage creates the photo planner page with grid overlay on Leaflet map.
// The JS (planner.js) expects #map, radio buttons, stats elements, etc.
func PhotoPlannerPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.PhotoPlannerURL(), "Planer dla zdjęć",
		[]string{"core", "leaflet"}, []string{"planner"},
		"/js/self/planner.js",
		views.ShellPlannerContent(),
	)
}

// TripIdeasPage creates the trip ideas shell page.
// Uses Preact with <div id="root"> — self-rendering JS component.
func TripIdeasPage(data *index.SiteData, rtr *router.Router, resolver *bundle.Resolver) Renderable {
	return shellPage(data, rtr, resolver,
		rtr.TripIdeasURL(), "Pomysły na trasy",
		[]string{"core", "leaflet", "react-runtime"}, []string{"ideas"},
		"/js/self/ideas.js",
		views.ShellContent(),
	)
}
