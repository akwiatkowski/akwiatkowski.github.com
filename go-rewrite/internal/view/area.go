package view

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/components"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// AreaShowPage creates a Renderable for an area show page.
func AreaShowPage(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	resolver *bundle.Resolver,
	polygonDir string,
) Renderable {
	url := r.AreaShowURL(area)

	// Build the JSON data blob as a raw <script> tag
	jsonData := buildAreaShowJSON(data, area, r, polygonDir)
	rawScript := `<script id="area-data" type="application/json">` + jsonData + `</script>`

	// Resolve assets
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "leaflet", "react-runtime"}, nil)

	page := layout.PageData{
		Title:        area.Name,
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJS:       "/js/self/area_show.js",
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.AreaShowContent(rawScript), true)
}

// AreaPostListPage creates a Renderable for an area post list page.
func AreaPostListPage(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.AreaPostListURL(area)

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "post-collection-js"}, nil)

	page := layout.PageData{
		Title:        fmt.Sprintf("Wpisy dla: %s", area.Name),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	configJSON := fmt.Sprintf(`{"filterBy":"%s","filterValue":"%s"}`, //nolint:gocritic // raw JSON template, %q would break output
		area.Type.String(), area.Slug)
	rawScript := `<script id="post-collection-config" type="application/json">` + configJSON + `</script>`

	return NewHTMLPage(url, page, views.AreaPostListContent(rawScript), true)
}

// AreaGalleryPage creates a Renderable for an area gallery page.
func AreaGalleryPage(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.AreaGalleryURL(area)

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"gallery"})

	page := layout.PageData{
		Title:        fmt.Sprintf("Galeria: %s", area.Name),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	// Collect photos for this area
	posts := data.PostsForArea(area.Type, area.Slug)
	photoCards := collectPhotoCards(posts, r)

	return NewHTMLPage(url, page, views.AreaGalleryContent(photoCards), true)
}

// buildAreaShowJSON creates the JSON blob inlined in area show pages.
func buildAreaShowJSON(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	polygonDir string,
) string {
	posts := data.PostsForArea(area.Type, area.Slug)

	type postEntry struct {
		Title    string  `json:"title"`
		URL      string  `json:"url"`
		Date     string  `json:"date"`
		Distance float64 `json:"distance,omitempty"`
		ImageURL string  `json:"image_url,omitempty"`
	}

	type areaJSON struct {
		Name     string      `json:"name"`
		Type     string      `json:"type"`
		Slug     string      `json:"slug"`
		BBox     *model.BBox `json:"bbox,omitempty"`
		Posts    []postEntry `json:"posts"`
		Polygon  json.RawMessage `json:"polygon,omitempty"`
	}

	aj := areaJSON{
		Name: area.Name,
		Type: area.Type.String(),
		Slug: area.Slug,
		BBox: area.BBox,
	}

	for _, post := range posts {
		pe := postEntry{
			Title:    post.Title,
			URL:      r.PostURL(post),
			Date:     post.Date.Format("2006-01-02"),
			Distance: post.Distance,
		}
		if post.ImageFilename != "" {
			pe.ImageURL = r.PostImageURL(post, post.ImageFilename)
		}
		aj.Posts = append(aj.Posts, pe)
	}

	// Try to load polygon GeoJSON
	if polygonDir != "" {
		polyPath := filepath.Join(polygonDir, area.Type.EnglishPlural(), area.Slug+".json")
		if polyData, err := os.ReadFile(polyPath); err == nil {
			aj.Polygon = json.RawMessage(polyData)
		}
	}

	jsonBytes, _ := json.Marshal(aj)
	return string(jsonBytes)
}

// collectPhotoCards builds PhotoCardData from all photos in the given posts.
func collectPhotoCards(posts []*model.Post, r *router.Router) []components.PhotoCardData {
	var cards []components.PhotoCardData
	for _, post := range posts {
		for _, photo := range post.PublishedPhotos {
			cards = append(cards, components.PhotoCardData{
				JPEGSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
				AVIFSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
				Alt:     photo.Desc,
			})
		}
	}
	return cards
}

// resolveAssets resolves bundles and page assets, handling nil resolver gracefully.
func resolveAssets(resolver *bundle.Resolver, bundles []string, pageAssets []string) (css, js []bundle.AssetFile) {
	if resolver == nil {
		return nil, nil
	}
	assets := resolver.Resolve(bundles)
	if len(pageAssets) > 0 {
		assets = append(assets, resolver.ResolvePageAssets(pageAssets)...)
	}
	return splitAssets(assets)
}

// splitAssets separates asset files into CSS and JS lists.
func splitAssets(assets []bundle.AssetFile) (css, js []bundle.AssetFile) {
	for _, a := range assets {
		if a.IsCSS {
			css = append(css, a)
		} else {
			js = append(js, a)
		}
	}
	return
}

// navStatsFromIndex converts index.NavStats to layout.NavStats with nav links.
func navStatsFromIndex(ns index.NavStats, r *router.Router, tagBySlug map[string]*model.Tag) layout.NavStats {
	tagURL := func(slug string) string {
		if tag, ok := tagBySlug[slug]; ok {
			return r.TagPostListURL(tag)
		}
		return "#"
	}
	return layout.NavStats{
		BicycleDistance: ns.BicycleDistance,
		BicycleTime:    ns.BicycleTime,
		BicycleCount:   ns.BicycleCount,
		HikeDistance:    ns.HikeDistance,
		HikeTime:       ns.HikeTime,
		HikeCount:      ns.HikeCount,
		SelfDistance:    ns.SelfDistance,
		SelfTime:       ns.SelfTime,
		Links: layout.NavLinks{
			RoweremURL:   tagURL("bicycle"),
			PieszoURL:    tagURL("hike"),
			NajlepszeURL: tagURL("best"),
			MapURL:       r.MapURL(),
		},
	}
}
