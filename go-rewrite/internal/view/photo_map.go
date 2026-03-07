package view

import (
	"fmt"
	"io"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	svgpkg "odkrywajac/internal/svg"
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

func buildPhotoMapData(data *index.SiteData) svgpkg.PhotoMapData {
	var photos []*model.Photo
	var routes []svgpkg.RouteData
	postBySlug := make(map[string]*model.Post)

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		postBySlug[post.Slug] = post

		for _, photo := range post.PhotoEntities {
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

	return svgpkg.PhotoMapData{
		Photos:      photos,
		Routes:      routes,
		PostBySlug:  postBySlug,
		RouteColors: data.RouteColors,
	}
}

// --- Global SVG Maps ---

// GlobalMapSVGs creates Renderables for all global photo map variants.
func GlobalMapSVGs(data *index.SiteData) []Renderable {
	mapData := buildPhotoMapData(data)
	var result []Renderable

	for _, v := range globalMapVariants {
		v := v // capture
		url := fmt.Sprintf("/mapa_zdjec/%s.svg", v.Slug)
		config := svgpkg.MapConfig{
			Zoom:       v.Zoom,
			PhotoSize:  v.PhotoSize,
			Width:      1000,
			DrawPhotos: v.PhotoSize > 0 && !v.DrawDots,
			DrawRoutes: true,
			DrawDots:   v.DrawDots,
		}
		result = append(result, NewRawEndpoint(url, false, func(w io.Writer) error {
			return svgpkg.RenderSVG(w, config, mapData)
		}))
	}

	return result
}

// --- Voivodeship SVG Maps ---

// VoivodeshipMapSVGs creates big and small SVG maps for each voivodeship.
func VoivodeshipMapSVGs(data *index.SiteData) []Renderable {
	var result []Renderable

	voivodeships := data.AreasByType[model.AreaTypeVoivodeship]
	for _, voiv := range voivodeships {
		posts := data.PostsForArea(voiv.Type, voiv.Slug)
		if len(posts) == 0 {
			continue
		}

		mapData := buildFilteredMapData(posts, data)

		for _, variant := range []struct {
			suffix    string
			zoom      int
			photoSize int
		}{
			{"_big", 10, 100},
			{"_small", 9, 80},
		} {
			v := variant
			url := fmt.Sprintf("/mapa_zdjec/wojewodztwo/%s%s.svg", voiv.Slug, v.suffix)
			config := svgpkg.MapConfig{
				Zoom:       v.zoom,
				PhotoSize:  v.photoSize,
				Width:      1000,
				DrawPhotos: true,
				DrawRoutes: true,
			}
			if voiv.BBox != nil {
				config.UseFixedBounds = true
				config.FixedLatMin = voiv.BBox.South
				config.FixedLatMax = voiv.BBox.North
				config.FixedLonMin = voiv.BBox.West
				config.FixedLonMax = voiv.BBox.East
			}
			result = append(result, NewRawEndpoint(url, false, func(w io.Writer) error {
				return svgpkg.RenderSVG(w, config, mapData)
			}))
		}
	}

	return result
}

// --- Post SVG Maps ---

// PostMapSVGs creates photo maps for posts with routes.
func PostMapSVGs(data *index.SiteData, r *router.Router) []Renderable {
	var result []Renderable

	for _, post := range data.Posts {
		if !post.IsFinished() || !post.HasRoutes() {
			continue
		}
		post := post // capture

		mapData := buildFilteredMapData([]*model.Post{post}, data)

		// Big post map (photos + routes)
		urlBig := fmt.Sprintf("/mapa_zdjec/wpis/%s_big.svg", post.Slug)
		configBig := svgpkg.MapConfig{
			Zoom:       10,
			PhotoSize:  120,
			Width:      1000,
			DrawPhotos: true,
			DrawRoutes: true,
		}
		result = append(result, NewRawEndpoint(urlBig, false, func(w io.Writer) error {
			return svgpkg.RenderSVG(w, configBig, mapData)
		}))

		// Small post map (dots + routes)
		urlSmall := fmt.Sprintf("/mapa_zdjec/wpis/%s.svg", post.Slug)
		configSmall := svgpkg.MapConfig{
			Zoom:       10,
			Width:      1000,
			DrawPhotos: false,
			DrawRoutes: true,
			DrawDots:   true,
		}
		result = append(result, NewRawEndpoint(urlSmall, false, func(w io.Writer) error {
			return svgpkg.RenderSVG(w, configSmall, mapData)
		}))
	}

	return result
}

// --- Tag SVG Maps ---

// TagMapSVGs creates SVG maps for tagged photos.
func TagMapSVGs(data *index.SiteData) []Renderable {
	var result []Renderable

	tagSlugs := []string{"bicycle", "hike", "walk", "train", "good", "best", "landscape", "rural", "urban"}

	for _, slug := range tagSlugs {
		slug := slug
		posts := data.PostsForTag(slug)
		if len(posts) == 0 {
			continue
		}

		mapData := buildFilteredMapData(posts, data)

		url := fmt.Sprintf("/mapa_zdjec/tagu/%s.svg", slug)
		config := svgpkg.MapConfig{
			Zoom:       8,
			PhotoSize:  80,
			Width:      1000,
			DrawPhotos: true,
			DrawRoutes: true,
		}
		result = append(result, NewRawEndpoint(url, false, func(w io.Writer) error {
			return svgpkg.RenderSVG(w, config, mapData)
		}))
	}

	return result
}

// --- Helper ---

func buildFilteredMapData(posts []*model.Post, data *index.SiteData) svgpkg.PhotoMapData {
	var photos []*model.Photo
	var routes []svgpkg.RouteData
	postBySlug := make(map[string]*model.Post)

	for _, post := range posts {
		if !post.IsFinished() {
			continue
		}
		postBySlug[post.Slug] = post

		for _, photo := range post.PhotoEntities {
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

	return svgpkg.PhotoMapData{
		Photos:      photos,
		Routes:      routes,
		PostBySlug:  postBySlug,
		RouteColors: data.RouteColors,
	}
}
