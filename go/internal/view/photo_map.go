package view

import (
	"fmt"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	svgpkg "odkrywajac/internal/service/svg"
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
		if !post.IsFinished() || !post.HasRoutes() {
			continue
		}

		photos, routes, postBySlug := collectFilteredMapData([]*model.Post{post}, data)

		// Big post map (photos + routes)
		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:         fmt.Sprintf("/mapa_zdjec/wpis/%s_big.svg", post.Slug),
			Zoom:        10,
			PhotoSize:   120,
			Width:       1000,
			DrawPhotos:  true,
			DrawRoutes:  true,
			Photos:      photos,
			Routes:      routes,
			PostBySlug:  postBySlug,
			RouteColors: data.RouteColors,
		}))

		// Small post map (dots + routes)
		result = append(result, svgpkg.NewSvgMapView(svgpkg.SvgMapParams{
			URL:        fmt.Sprintf("/mapa_zdjec/wpis/%s.svg", post.Slug),
			Zoom:       10,
			Width:      1000,
			DrawRoutes: true,
			DrawDots:   true,
			Photos:     photos,
			Routes:     routes,
			PostBySlug: postBySlug,
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
