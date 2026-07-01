package view

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
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
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "leaflet", "react-runtime"}, []string{"area-show"})

	page := layout.PageData{
		Title:        area.Name,
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJSFiles:       []string{"/js/self/area_show.js"},
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
// Uses the dynamic JS gallery with lightbox (same as post and tag galleries).
func AreaGalleryPage(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.AreaGalleryURL(area)
	title := fmt.Sprintf("Galeria: %s", area.Name)
	posts := data.PostsForArea(area.Type, area.Slug)
	photos := collectPhotosFromPosts(posts)
	return galleryPage(data, r, resolver, url, title, photos)
}

// buildAreaShowJSON creates the JSON blob inlined in area show pages.
// Matches Crystal's area_show.jsx data contract: posts with tags/coords,
// photos, related areas, bbox (lowercase), voivodeship info, etc.
func buildAreaShowJSON(
	data *index.SiteData,
	area *model.Area,
	r *router.Router,
	polygonDir string,
) string {
	posts := data.PostsForArea(area.Type, area.Slug)

	// --- Post entries with full data for JS rendering ---
	type coordSegment struct {
		Route [][]float64 `json:"route"`
	}
	type postEntry struct {
		URL             string         `json:"url"`
		Slug            string         `json:"slug"`
		Title           string         `json:"title"`
		Date            string         `json:"date"`
		Distance        float64        `json:"distance,omitempty"`
		TimeSpent       float64        `json:"time_spent,omitempty"`
		CardImageURL    string         `json:"card_image_url,omitempty"`
		CardImageAVIF   string         `json:"card_image_url_avif,omitempty"`
		Tags            []string       `json:"tags"`
		Coords          []coordSegment `json:"coords,omitempty"`
	}

	// --- Photo entries for the photos grid ---
	type photoEntry struct {
		Desc           string `json:"desc"`
		ArticleURL     string `json:"article_url"`
		ArticleAVIF    string `json:"article_url_avif"`
		GridURL        string `json:"grid_url"`
		GridAVIF       string `json:"grid_url_avif"`
		Time           string `json:"time,omitempty"`
		PostURL        string `json:"post_url"`
		Points         int    `json:"points"`
	}

	// --- BBox with lowercase JSON keys (matching JS expectations) ---
	type bboxJSON struct {
		South float64 `json:"south"`
		North float64 `json:"north"`
		West  float64 `json:"west"`
		East  float64 `json:"east"`
	}

	type areaJSON struct {
		Slug             string            `json:"slug"`
		Name             string            `json:"name"`
		AreaType         string            `json:"areaType"`
		AreaTypeLabel    string            `json:"areaTypeLabel"`
		ParentName       string            `json:"parentName,omitempty"`
		ParentURL        string            `json:"parentUrl,omitempty"`
		VoivodeshipName  string            `json:"voivodeshipName,omitempty"`
		VoivodeshipURL   string            `json:"voivodeshipUrl,omitempty"`
		PostListURL      string            `json:"postListUrl"`
		GalleryURL       string            `json:"galleryUrl"`
		BestPhotoURL     string            `json:"bestPhotoUrl,omitempty"`
		BestPhotoAVIF    string            `json:"bestPhotoUrlAvif,omitempty"`
		BBox             *bboxJSON         `json:"bbox,omitempty"`
		Polygon          json.RawMessage   `json:"polygon,omitempty"`
		Posts            []postEntry        `json:"posts"`
		Photos           []photoEntry       `json:"photos"`
		RelatedAreas     []areaRelatedEntry `json:"related_areas"`
	}

	aj := areaJSON{
		Slug:          area.Slug,
		Name:          area.Name,
		AreaType:      area.Type.String(),
		AreaTypeLabel: area.Type.NominativeSlug(),
		PostListURL:   r.AreaPostListURL(area),
		GalleryURL:    r.AreaGalleryURL(area),
		Posts:         []postEntry{},
		Photos:        []photoEntry{},
		RelatedAreas:  []areaRelatedEntry{},
	}

	// BBox with lowercase keys
	if area.BBox != nil {
		aj.BBox = &bboxJSON{
			South: area.BBox.South,
			North: area.BBox.North,
			West:  area.BBox.West,
			East:  area.BBox.East,
		}
	}

	// Voivodeship parent info
	if area.VoivodeshipSlug != "" {
		voivArea := data.FindArea(model.AreaTypeVoivodeship, area.VoivodeshipSlug)
		if voivArea != nil {
			aj.VoivodeshipName = voivArea.Name
			aj.VoivodeshipURL = r.AreaShowURL(voivArea)
			// ParentName is the immediate parent (county for towns, voivodeship for counties).
			// Since we don't have county data for towns, only set ParentName for
			// meso/macro regions where it differs from the voivodeship.
			// This avoids the JS rendering "wielkopolskie, wielkopolskie" in the hero.
			if area.Type == model.AreaTypeMesoRegion || area.Type == model.AreaTypeMacroRegion {
				aj.ParentName = voivArea.Name
				aj.ParentURL = r.AreaShowURL(voivArea)
			}
		}
	}

	// Build posts and collect photos
	var bestPhoto *model.Photo
	var bestPhotoPost *model.Post
	for _, post := range posts {
		pe := postEntry{
			URL:       r.PostURL(post),
			Slug:      post.Slug,
			Title:     post.Title,
			Date:      post.Date.Format("2006-01-02"),
			Distance:  post.Distance,
			TimeSpent: post.TimeSpent,
			Tags:      post.TagSlugs,
		}
		if post.ImageFilename != "" {
			pe.CardImageURL = r.ProcessedImageURL(post, post.ImageFilename, "card", "jpg")
			pe.CardImageAVIF = r.ProcessedImageURL(post, post.ImageFilename, "card", "avif")
		}

		// Route coordinates
		for _, route := range post.Routes {
			for _, seg := range route.Segments {
				coords := make([][]float64, len(seg))
				for i, ll := range seg {
					coords[i] = []float64{ll.Lat, ll.Lon}
				}
				pe.Coords = append(pe.Coords, coordSegment{Route: coords})
			}
		}

		aj.Posts = append(aj.Posts, pe)

		// Collect photos from this post
		for _, photo := range post.PublishedPhotos {
			phe := photoEntry{
				Desc:        photo.Desc,
				ArticleURL:  r.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
				ArticleAVIF: r.ProcessedImageURL(post, photo.ImageFilename, "article", "avif"),
				GridURL:     r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
				GridAVIF:    r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
				PostURL:     r.PostURL(post),
				Points:      photo.Points,
			}
			if photo.HasTime() {
				phe.Time = photo.Exif.Time.Format("2006-01-02T15:04:05-07:00")
			}
			aj.Photos = append(aj.Photos, phe)

			// Track best photo by points for hero image
			if bestPhoto == nil || photo.Points > bestPhoto.Points {
				bestPhoto = photo
				bestPhotoPost = post
			}
		}
	}

	// Best photo for hero background
	if bestPhoto != nil && bestPhotoPost != nil {
		aj.BestPhotoURL = r.ProcessedImageURL(bestPhotoPost, bestPhoto.ImageFilename, "article", "jpg")
		aj.BestPhotoAVIF = r.ProcessedImageURL(bestPhotoPost, bestPhoto.ImageFilename, "article", "avif")
	}

	// Related areas: find areas that share posts with this one
	aj.RelatedAreas = buildRelatedAreas(data, area, r)

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

// areaRelatedEntry is a JSON-serializable related area entry for the area show page.
type areaRelatedEntry struct {
	Name          string `json:"name"`
	Slug          string `json:"slug"`
	AreaType      string `json:"area_type"`
	ShowURL       string `json:"show_url"`
	BestPhotoURL  string `json:"best_photo_url,omitempty"`
	BestPhotoAVIF string `json:"best_photo_url_avif,omitempty"`
}

// buildRelatedAreas finds areas that share posts with the given area.
// Scores by shared post count, returns top results.
func buildRelatedAreas(data *index.SiteData, area *model.Area, r *router.Router) []areaRelatedEntry {
	posts := data.PostsForArea(area.Type, area.Slug)
	scores := make(map[string]int)

	for _, post := range posts {
		for _, slug := range post.TownSlugs {
			for _, areaType := range model.AllAreaTypes() {
				otherArea := data.FindArea(areaType, slug)
				if otherArea != nil && otherArea.MapKey() != area.MapKey() {
					scores[otherArea.MapKey()]++
				}
			}
		}
		for _, slug := range post.LandSlugs {
			for _, areaType := range []model.AreaType{model.AreaTypeMesoRegion, model.AreaTypeMacroRegion} {
				otherArea := data.FindArea(areaType, slug)
				if otherArea != nil && otherArea.MapKey() != area.MapKey() {
					scores[otherArea.MapKey()]++
				}
			}
		}
	}

	type scored struct {
		key   string
		score int
	}
	var scoredList []scored
	for key, score := range scores {
		scoredList = append(scoredList, scored{key, score})
	}
	sort.Slice(scoredList, func(i, j int) bool {
		return scoredList[i].score > scoredList[j].score
	})

	limit := 6
	if len(scoredList) < limit {
		limit = len(scoredList)
	}

	result := make([]areaRelatedEntry, 0, limit)
	for i := 0; i < limit; i++ {
		otherArea := data.FindAreaByMapKey(scoredList[i].key)
		if otherArea == nil {
			continue
		}

		entry := areaRelatedEntry{
			Name:     otherArea.Name,
			Slug:     otherArea.Slug,
			AreaType: otherArea.Type.NominativeSlug(),
			ShowURL:  r.AreaShowURL(otherArea),
		}

		// Find best photo from posts in this related area
		relatedPosts := data.PostsForArea(otherArea.Type, otherArea.Slug)
		var bestPhoto *model.Photo
		var bestPhotoPost *model.Post
		for _, post := range relatedPosts {
			for _, photo := range post.PublishedPhotos {
				if bestPhoto == nil || photo.Points > bestPhoto.Points {
					bestPhoto = photo
					bestPhotoPost = post
				}
			}
		}
		if bestPhoto != nil && bestPhotoPost != nil {
			entry.BestPhotoURL = r.ProcessedImageURL(bestPhotoPost, bestPhoto.ImageFilename, "grid", "jpg")
			entry.BestPhotoAVIF = r.ProcessedImageURL(bestPhotoPost, bestPhoto.ImageFilename, "grid", "avif")
		}

		result = append(result, entry)
	}

	return result
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
