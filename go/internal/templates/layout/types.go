// Package layout provides the page shell templ components (head, nav, footer).
package layout

import "odkrywajac/internal/bundle"

// PageData holds all data needed to render the page shell.
type PageData struct {
	Title        string // Page title (before " - Site Title")
	Subtitle     string
	Desc         string // meta description
	URL          string // page URL path (e.g. "/gmina/pobiedziska.html")
	CanonicalURL string // full canonical URL
	ImageURL     string // og:image URL
	SiteName     string // site name for og:site_name

	// Resolved asset files
	CSSFiles []bundle.AssetFile
	JSFiles  []bundle.AssetFile
	// Page-specific JS files, rendered with `defer` so they run after the DOM
	// is parsed. Bundle JS in JSFiles loads synchronously (libraries like
	// Preact/Leaflet must exist before inline scripts); page apps that touch
	// the DOM (e.g. photo_map.js rendering into #root) must defer instead.
	PageJSFiles []string

	// Extra raw HTML to inject into <head> (e.g. Google Fonts)
	ExtraHead string

	// Navigation stats
	NavStats NavStats
}

// NavLinks holds pre-computed URLs for the navigation bar.
type NavLinks struct {
	RoweremURL   string
	PieszoURL    string
	NajlepszeURL string
	MapURL       string
}

// NavStats holds pre-computed navigation statistics for the nav bar.
type NavStats struct {
	BicycleDistance int
	BicycleTime    int
	BicycleCount   int
	HikeDistance    int
	HikeTime       int
	HikeCount      int
	SelfDistance    int
	SelfTime       int
	Links          NavLinks
}

// FullTitle returns the page title with site name suffix.
func (p PageData) FullTitle() string {
	if p.Title == "" {
		return p.SiteName
	}
	return p.Title + " - " + p.SiteName
}
