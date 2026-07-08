package view

import (
	"fmt"
	"math"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	svgpkg "odkrywajac/internal/service/svg"
)

// Post route-map sizing. The output SVG is always postMapWidth wide and its
// content is scaled to fit, so zoom only controls raster-tile crispness. We
// auto-pick the zoom per post from its bounding box (see svg.FitZoom) instead
// of a fixed value or the frontmatter map_zooms, which the Go engine ignored.
const (
	postMapWidth       = 1000.0 // output SVG width in px (matches SvgMapParams default)
	postMapMinZoom     = 6      // lowest UMP tile zoom available locally
	postMapMaxZoom     = 16     // highest UMP tile zoom available locally
	postMapDefaultZoom = 11     // fallback when a post has no boundable content
)

// --- Map Configurations ---

type mapVariant struct {
	Slug      string
	Zoom      int
	PhotoSize int
	DrawDots  bool
}

var globalMapVariants = []mapVariant{
	{Slug: "overall", Zoom: 10, PhotoSize: 200},
	{Slug: "coarse", Zoom: 8, PhotoSize: 160},
	{Slug: "small", Zoom: 8, PhotoSize: 100},
	{Slug: "detailed", Zoom: 10, PhotoSize: 50},
	{Slug: "small_detailed", Zoom: 8, PhotoSize: 25},
	{Slug: "dots", Zoom: 10, PhotoSize: 0, DrawDots: true},
}

// --- Photo Map Data Builder ---

func collectPhotoMapData(data *catalog.SiteData) ([]*model.Photo, []svgpkg.RouteData, map[string]*model.Post) {
	var photos []*model.Photo
	var routes []svgpkg.RouteData
	postBySlug := make(map[string]*model.Post)

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		postBySlug[post.Slug] = post

		for _, photo := range post.PublishedPhotos {
			if photo.HasGPS() {
				photos = append(photos, photo)
			}
		}

		for _, route := range post.Routes {
			routes = append(routes, svgpkg.RouteData{
				Type:     route.Type,
				Segments: route.Segments,
			})
		}
	}

	return photos, routes, postBySlug
}

func collectFilteredMapData(posts []*model.Post, _ *catalog.SiteData) ([]*model.Photo, []svgpkg.RouteData, map[string]*model.Post) {
	var photos []*model.Photo
	var routes []svgpkg.RouteData
	postBySlug := make(map[string]*model.Post)

	for _, post := range posts {
		if !post.IsFinished() {
			continue
		}
		postBySlug[post.Slug] = post

		for _, photo := range post.PublishedPhotos {
			if photo.HasGPS() {
				photos = append(photos, photo)
			}
		}

		for _, route := range post.Routes {
			routes = append(routes, svgpkg.RouteData{
				Type:     route.Type,
				Segments: route.Segments,
			})
		}
	}

	return photos, routes, postBySlug
}

// collectPostMapData gathers a single post's GPS photos and routes for its own
// route map. Unlike collectFilteredMapData it does NOT skip unfinished posts: a
// draft's own page still shows its route (PostMapSVGs already gates on
// HasRoutes). Aggregate maps (voivodeship, tag) keep the finished-only filter so
// drafts don't leak onto public overview maps.
func collectPostMapData(post *model.Post) ([]*model.Photo, []svgpkg.RouteData, map[string]*model.Post) {
	photos := make([]*model.Photo, 0, len(post.PublishedPhotos))
	for _, photo := range post.PublishedPhotos {
		if photo.HasGPS() {
			photos = append(photos, photo)
		}
	}
	routes := make([]svgpkg.RouteData, 0, len(post.Routes))
	for _, route := range post.Routes {
		routes = append(routes, svgpkg.RouteData{Type: route.Type, Segments: route.Segments})
	}
	return photos, routes, map[string]*model.Post{post.Slug: post}
}

// mapContentBounds returns the lat/lon bounding box covering all route points
// and GPS photos — the same content RenderSVG frames. ok is false when there is
// nothing to bound.
func mapContentBounds(photos []*model.Photo, routes []svgpkg.RouteData) (latMin, latMax, lonMin, lonMax float64, ok bool) {
	latMin, lonMin = math.Inf(1), math.Inf(1)
	latMax, lonMax = math.Inf(-1), math.Inf(-1)
	add := func(lat, lon float64) {
		ok = true
		latMin, latMax = math.Min(latMin, lat), math.Max(latMax, lat)
		lonMin, lonMax = math.Min(lonMin, lon), math.Max(lonMax, lon)
	}
	for _, route := range routes {
		for _, seg := range route.Segments {
			for _, ll := range seg {
				add(ll.Lat, ll.Lon)
			}
		}
	}
	for _, photo := range photos {
		if photo.HasGPS() {
			add(*photo.Exif.Lat, *photo.Exif.Lon)
		}
	}
	return
}

// --- Global SVG Maps ---

// GlobalMapSVGs creates Renderables for all global photo map variants.
func GlobalMapSVGs(data *catalog.SiteData) []Renderable {
	photos, routes, postBySlug := collectPhotoMapData(data)
	var result []Renderable

	for _, v := range globalMapVariants {
		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:         fmt.Sprintf("/mapa_zdjec/%s.svg", v.Slug),
			Zoom:        v.Zoom,
			PhotoSize:   v.PhotoSize,
			Width:       1000,
			DrawPhotos:  v.PhotoSize > 0 && !v.DrawDots,
			DrawRoutes:  true,
			DrawDots:    v.DrawDots,
			Photos:      photos,
			Routes:      routes,
			PostBySlug:  postBySlug,
			RouteColors: data.RouteColors,
		}))
	}

	return result
}

// --- Voivodeship SVG Maps ---

// VoivodeshipMapSVGs creates big and small SVG maps for each voivodeship.
func VoivodeshipMapSVGs(data *catalog.SiteData) []Renderable {
	var result []Renderable

	voivodeships := data.AreasByType[model.AreaTypeVoivodeship]
	for _, voiv := range voivodeships {
		posts := data.PostsForArea(voiv.Type, voiv.Slug)
		if len(posts) == 0 {
			continue
		}

		photos, routes, postBySlug := collectFilteredMapData(posts, data)

		for _, variant := range []struct {
			suffix    string
			zoom      int
			photoSize int
		}{
			{"_big", 10, 100},
			{"_small", 9, 80},
		} {
			params := svgpkg.SvgMapParams{
				URL:         fmt.Sprintf("/mapa_zdjec/wojewodztwo/%s%s.svg", voiv.Slug, variant.suffix),
				Zoom:        variant.zoom,
				PhotoSize:   variant.photoSize,
				Width:       1000,
				DrawPhotos:  true,
				DrawRoutes:  true,
				Photos:      photos,
				Routes:      routes,
				PostBySlug:  postBySlug,
				RouteColors: data.RouteColors,
			}
			if voiv.BBox != nil {
				params.UseFixedBounds = true
				params.FixedBounds = [4]float64{voiv.BBox.South, voiv.BBox.North, voiv.BBox.West, voiv.BBox.East}
			}
			result = append(result, svgpkg.NewSvgMapView(params))
		}
	}

	return result
}

// --- Post SVG Maps ---

// PostMapSVGs creates photo maps for posts with routes.
func PostMapSVGs(data *catalog.SiteData, r *router.Router) []Renderable {
	var result []Renderable

	for _, post := range data.Posts {
		// Generate a route map whenever the post has a route, regardless of
		// finished state. The post article references the map on HasRoutes()
		// alone (see view/post.go), so gating generation on IsFinished() too
		// would leave unfinished-but-routed drafts pointing at a missing SVG.
		if !post.HasRoutes() {
			continue
		}

		photos, routes, postBySlug := collectPostMapData(post)

		// Auto-pick zoom so the route bbox fills the fixed-width output crisply,
		// rather than the old hardcoded 10 (which up-scaled small trips → blurry).
		zoom := postMapDefaultZoom
		if latMin, latMax, lonMin, lonMax, ok := mapContentBounds(photos, routes); ok {
			zoom = svgpkg.FitZoom(latMin, latMax, lonMin, lonMax,
				postMapWidth-2*svgpkg.BoundsPadding, postMapMinZoom, postMapMaxZoom)
		}

		// Big post map (photos + routes)
		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:         router.PostMapPath(post, "_big.svg"),
			Zoom:        zoom,
			PhotoSize:   120,
			Width:       int(postMapWidth),
			DrawPhotos:  true,
			DrawRoutes:  true,
			Photos:      photos,
			Routes:      routes,
			PostBySlug:  postBySlug,
			RouteColors: data.RouteColors,
		}))

		// Small post map (dots + routes)
		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:         router.PostMapPath(post, ".svg"),
			Zoom:        zoom,
			Width:       int(postMapWidth),
			DrawRoutes:  true,
			DrawDots:    true,
			Photos:      photos,
			Routes:      routes,
			PostBySlug:  postBySlug,
			RouteColors: data.RouteColors,
		}))
	}

	return result
}

// --- Tag SVG Maps ---

// TagMapSVGs creates SVG maps for tagged photos.
func TagMapSVGs(data *catalog.SiteData) []Renderable {
	var result []Renderable

	tagSlugs := []string{"bicycle", "hike", "walk", "train", "good", "best", "landscape", "rural", "urban"}

	for _, slug := range tagSlugs {
		posts := data.PostsForTag(slug)
		if len(posts) == 0 {
			continue
		}

		photos, routes, postBySlug := collectFilteredMapData(posts, data)

		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:         fmt.Sprintf("/mapa_zdjec/tagu/%s.svg", slug),
			Zoom:        8,
			PhotoSize:   80,
			Width:       1000,
			DrawPhotos:  true,
			DrawRoutes:  true,
			Photos:      photos,
			Routes:      routes,
			PostBySlug:  postBySlug,
			RouteColors: data.RouteColors,
		}))
	}

	return result
}
