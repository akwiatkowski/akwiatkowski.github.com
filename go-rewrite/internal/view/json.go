package view

import (
	"fmt"
	"io"
	"sort"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

// E2EJSON creates a JSON endpoint with all post data for E2E tests.
func E2EJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type postEntry struct {
		URL           string   `json:"url"`
		Ready         bool     `json:"ready"`
		PhotosCount   int      `json:"photos_count"`
		HasRoute      bool     `json:"has_route"`
		Tags          []string `json:"tags"`
		Voivodeships  []string `json:"voivodeships"`
	}

	type tagEntry struct {
		URL  string `json:"url"`
		Slug string `json:"slug"`
	}

	type voivEntry struct {
		Slug       string `json:"slug"`
		ShowURL    string `json:"show_url"`
		GalleryURL string `json:"gallery_url"`
	}

	type e2eData struct {
		Posts        []postEntry `json:"posts"`
		Tags         []tagEntry  `json:"tags"`
		Voivodeships []voivEntry `json:"voivodeships"`
	}

	result := e2eData{}
	for _, post := range data.Posts {
		tags := post.TagSlugs
		if tags == nil {
			tags = []string{}
		}
		voivSlugs := data.VoivodeshipSlugsForPost(post)
		if voivSlugs == nil {
			voivSlugs = []string{}
		}
		result.Posts = append(result.Posts, postEntry{
			URL:          rtr.PostURL(post),
			Ready:        post.IsFinished(),
			PhotosCount:  len(post.PublishedPhotos),
			HasRoute:     post.HasRoutes(),
			Tags:         tags,
			Voivodeships: voivSlugs,
		})
	}

	for _, tag := range data.Tags {
		result.Tags = append(result.Tags, tagEntry{
			URL:  rtr.TagLinkURL(&tag),
			Slug: tag.Slug,
		})
	}

	voivAreas := data.AreasWithPosts[model.AreaTypeVoivodeship]
	for _, area := range voivAreas {
		result.Voivodeships = append(result.Voivodeships, voivEntry{
			Slug:       area.Slug,
			ShowURL:    rtr.AreaShowURL(area),
			GalleryURL: rtr.AreaGalleryURL(area),
		})
	}
	if result.Tags == nil {
		result.Tags = []tagEntry{}
	}
	if result.Voivodeships == nil {
		result.Voivodeships = []voivEntry{}
	}

	return NewJSONEndpoint(rtr.E2EJSON(), result)
}

// MapJSON creates a JSON endpoint for the route map page.
func MapJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type routeSegment struct {
		Type  string       `json:"type"`
		Route [][2]float64 `json:"route"`
	}

	type postEntry struct {
		URL       string         `json:"url"`
		Slug      string         `json:"slug"`
		Title     string         `json:"title"`
		Date      string         `json:"date"`
		Distance  float64        `json:"distance,omitempty"`
		TimeSpent float64        `json:"time_spent,omitempty"`
		CardImage string         `json:"card_image_url,omitempty"`
		CardAVIF  string         `json:"card_image_url_avif,omitempty"`
		Coords    []routeSegment `json:"coords"`
	}

	type mapData struct {
		Posts []postEntry `json:"posts"`
	}

	result := mapData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		if !hasRouteData(post) {
			continue
		}

		pe := postEntry{
			URL:       rtr.PostURL(post),
			Slug:      post.Slug,
			Title:     post.Title,
			Date:      post.Date.Format("2006-01-02"),
			Distance:  post.Distance,
			TimeSpent: post.TimeSpent,
		}
		if post.ImageFilename != "" {
			pe.CardImage = rtr.ProcessedImageURL(post, post.ImageFilename, "card", "jpg")
			pe.CardAVIF = rtr.ProcessedImageURL(post, post.ImageFilename, "card", "avif")
		}

		for _, route := range post.Routes {
			for _, seg := range route.Segments {
				var coords [][2]float64
				for _, pt := range seg {
					coords = append(coords, [2]float64{pt.Lat, pt.Lon})
				}
				if len(coords) > 0 {
					pe.Coords = append(pe.Coords, routeSegment{
						Type:  route.Type,
						Route: coords,
					})
				}
			}
		}

		result.Posts = append(result.Posts, pe)
	}

	return NewJSONEndpoint(rtr.MapJSON(), result)
}

// PhotosJSON creates a JSON endpoint with all photo metadata.
// Camera and lens names are humanized via model.CameraNames/LensNames dictionaries.
// Includes a tag_names map so the frontend can display Polish tag names.
func PhotosJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type photoEntry struct {
		Desc       string   `json:"desc"`
		FullURL    string   `json:"full_url"`
		ArticleURL string   `json:"article_url"`
		Time       string   `json:"time"`
		PostSlug   string   `json:"post_slug"`
		PostURL    string   `json:"post_url"`
		Points     int      `json:"points"`
		Tags       []string `json:"tags"`

		// EXIF fields (omitted if nil)
		Lat        *float64 `json:"exif.lat,omitempty"`
		Lon        *float64 `json:"exif.lon,omitempty"`
		Altitude   *float64 `json:"exif.altitude,omitempty"`
		Focal35mm  *float64 `json:"exif.focal_35mm,omitempty"`
		Aperture   *float64 `json:"exif.aperture,omitempty"`
		Exposure   *float64 `json:"exif.exposure,omitempty"`
		ISO        *int     `json:"exif.iso,omitempty"`
		LensName   string   `json:"exif.lens_name,omitempty"`
		CameraName string   `json:"exif.camera_name,omitempty"`
		ExifTime   string   `json:"exif.time,omitempty"`
	}

	type photosData struct {
		Photos   []photoEntry      `json:"photos"`
		TagNames map[string]string `json:"tag_names"`
	}

	// Build photo tag slug → Polish title map for frontend display
	tagNames := make(map[string]string, len(data.PhotoTags))
	for _, pt := range data.PhotoTags {
		tagNames[pt.Slug] = pt.Title
	}

	result := photosData{TagNames: tagNames}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if len(photo.Desc) < 4 {
				continue
			}
			var timeStr string
			if photo.Exif != nil && photo.Exif.Time != nil {
				timeStr = photo.Exif.Time.Format("2006-01-02T15:04:05+00:00")
			}

			pe := photoEntry{
				Desc:       photo.Desc,
				FullURL:    rtr.PostImageURL(post, photo.ImageFilename),
				ArticleURL: rtr.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
				Time:       timeStr,
				PostSlug:   post.Slug,
				PostURL:    rtr.PostURL(post),
				Points:     photo.Points,
				Tags:       photo.TagSlugs,
			}
			if photo.Exif != nil {
				pe.Lat = photo.Exif.Lat
				pe.Lon = photo.Exif.Lon
				pe.Altitude = photo.Exif.Altitude
				pe.Focal35mm = photo.Exif.FocalLength35
				pe.Aperture = photo.Exif.Aperture
				pe.Exposure = photo.Exif.Exposure
				pe.ISO = photo.Exif.ISO
				pe.LensName = photo.Exif.LensName
				pe.CameraName = photo.Exif.CameraName
				pe.ExifTime = timeStr
			}
			result.Photos = append(result.Photos, pe)
		}
	}

	return NewJSONEndpoint(rtr.PhotosJSON(), result)
}

// PhotosMapJSON creates a JSON endpoint with GPS-tagged photos for map markers.
// Field names use dot-notation (e.g. "exif.lat") to match Crystal's format
// and the photo_map.js frontend expectations.
func PhotosMapJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type photoEntry struct {
		Desc         string   `json:"desc"`
		FullURL      string   `json:"full_url"`
		ArticleURL   string   `json:"article_url"`
		ArticleAVIF  string   `json:"article_url_avif"`
		GridURL      string   `json:"grid_url"`
		GridAVIF     string   `json:"grid_url_avif"`
		ThumbnailURL string   `json:"thumbnail_url"`
		Time         string   `json:"time"`
		PostSlug     string   `json:"post_slug"`
		PostURL      string   `json:"post_url"`
		Points       int      `json:"points"`
		Tags         []string `json:"tags"`
		ExifLat      float64  `json:"exif.lat"`
		ExifLon      float64  `json:"exif.lon"`
		ExifAltitude *float64 `json:"exif.altitude"`
		ExifTime     string   `json:"exif.time,omitempty"`
		ExifCamera   string   `json:"exif.camera_name,omitempty"`
		ExifLens     string   `json:"exif.lens_name,omitempty"`
	}

	type photosMapData struct {
		Photos []photoEntry `json:"photos"`
	}

	result := photosMapData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if !photo.HasGPS() {
				continue
			}
			if len(photo.Desc) < 4 {
				continue
			}

			var timeStr string
			if photo.Exif.Time != nil {
				timeStr = photo.Exif.Time.Format("2006-01-02T15:04:05")
			}

			entry := photoEntry{
				Desc:         photo.Desc,
				FullURL:      rtr.PostImageURL(post, photo.ImageFilename),
				ArticleURL:   rtr.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
				ArticleAVIF:  rtr.ProcessedImageURL(post, photo.ImageFilename, "article", "avif"),
				GridURL:      rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
				GridAVIF:     rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
				ThumbnailURL: rtr.ProcessedImageURL(post, photo.ImageFilename, "thumbnail", "jpg"),
				Time:         timeStr,
				PostSlug:     post.Slug,
				PostURL:      rtr.PostURL(post),
				Points:       photo.Points,
				Tags:         photo.TagSlugs,
				ExifLat:      *photo.Exif.Lat,
				ExifLon:      *photo.Exif.Lon,
				ExifAltitude: photo.Exif.Altitude,
				ExifTime:     timeStr,
				ExifCamera:   photo.Exif.CameraName,
				ExifLens:     photo.Exif.LensName,
			}
			result.Photos = append(result.Photos, entry)
		}
	}

	return NewJSONEndpoint(rtr.PhotosMapJSON(), result)
}

// TrainStationsJSON creates a JSON endpoint for train station data.
func TrainStationsJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type stationEntry struct {
		Name         string  `json:"name"`
		Lat          float64 `json:"lat"`
		Lon          float64 `json:"lon"`
		TimeDistance float64 `json:"time_distance"`
	}

	type stationsData struct {
		TrainStations []stationEntry `json:"train_stations"`
	}

	result := stationsData{}
	for i := range data.Stations {
		s := &data.Stations[i]
		result.TrainStations = append(result.TrainStations, stationEntry{
			Name:         s.Name,
			Lat:          s.Lat,
			Lon:          s.Lon,
			TimeDistance: s.PoznanTimeDistance(),
		})
	}

	return NewJSONEndpoint(rtr.TrainStationsJSON(), result)
}

// PhotoGridJSON creates a JSON endpoint with photo GPS coordinates for the grid map.
func PhotoGridJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type gridData struct {
		Coords [][2]float64 `json:"coords"`
	}

	result := gridData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if !photo.HasGPS() {
				continue
			}
			result.Coords = append(result.Coords, [2]float64{*photo.Exif.Lat, *photo.Exif.Lon})
		}
	}

	return NewJSONEndpoint(rtr.PhotoGridJSON(), result)
}

// IdeasJSON creates a JSON endpoint for trip ideas data.
// Contains town metadata (for slug→name lookup) and idea entries with
// train station info, direction bearing, time cost stats, and visited town counts.
func IdeasJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type townEntry struct {
		Slug string  `json:"slug"`
		Name string  `json:"name"`
		URL  *string `json:"url"` // nil if the town has no show page
	}

	type stationInfo struct {
		Name         string  `json:"name"`
		Lat          float64 `json:"lat"`
		Lon          float64 `json:"lon"`
		TimeDistance float64 `json:"time_distance"`
	}

	type ideaEntry struct {
		Slug               string              `json:"slug"`
		Link               string              `json:"link"`
		Distance           int                 `json:"distance"`
		Elevation          *int                `json:"elevation"`
		DaysMinLegacy      int                 `json:"lindays_mink"`
		DaysMin            int                 `json:"days_min"`
		DaysNormal         int                 `json:"days_normal"`
		Start              stationInfo         `json:"start"`
		Finish             stationInfo         `json:"finish"`
		Direction          float64             `json:"direction"`
		DirectionChar      string              `json:"direction_char"`
		TimeCostStats      model.TimeCostStats `json:"time_cost_stats_for_new_town"`
		Surfaces           []string            `json:"surfaces"`
		Towns              []string            `json:"towns"`
		PhotoMapURL        string              `json:"photo_map_url"`
		TownsAlreadyVisit  int                 `json:"towns_already_visited"`
		TownsNotVisited    int                 `json:"towns_not_visited"`
	}

	type ideasData struct {
		Towns []townEntry `json:"towns"`
		Ideas []ideaEntry `json:"ideas"`
	}

	// Build visited town slugs from self-propelled posts (bicycle, hike, walk)
	visitedSlugs := make(map[string]bool)
	for _, post := range data.Posts {
		if !post.IsFinished() || !post.IsSelfPropelled() {
			continue
		}
		for _, slug := range post.TownSlugs {
			visitedSlugs[slug] = true
		}
	}

	// Build station lookup by name
	stationByName := make(map[string]*model.TrainStation, len(data.Stations))
	for i := range data.Stations {
		stationByName[data.Stations[i].Name] = &data.Stations[i]
	}

	// Towns with rendered show pages (those that have posts)
	townsWithPages := make(map[string]bool)
	for _, area := range data.AreasWithPosts[model.AreaTypeTown] {
		townsWithPages[area.Slug] = true
	}

	// Build towns array
	allTowns := data.AreasByType[model.AreaTypeTown]
	towns := make([]townEntry, 0, len(allTowns))
	for _, area := range allTowns {
		entry := townEntry{
			Slug: area.Slug,
			Name: area.Name,
		}
		if townsWithPages[area.Slug] {
			url := rtr.AreaShowURL(area)
			entry.URL = &url
		}
		towns = append(towns, entry)
	}

	// Build ideas array
	ideas := make([]ideaEntry, 0, len(data.Ideas))
	for _, idea := range data.Ideas {
		startStation := stationByName[idea.Start]
		finishStation := stationByName[idea.Finish]
		if startStation == nil || finishStation == nil {
			continue
		}

		direction := model.DirectionBearing(
			startStation.Lat, startStation.Lon,
			finishStation.Lat, finishStation.Lon,
		)

		totalTrainTime := int(startStation.PoznanTimeDistance() + finishStation.PoznanTimeDistance() + 0.999)
		timeCostStats := idea.ComputeTimeCostStats(visitedSlugs, totalTrainTime)

		surfaces := idea.Surfaces
		if surfaces == nil {
			surfaces = []string{}
		}
		ideaTowns := idea.Towns
		if ideaTowns == nil {
			ideaTowns = []string{}
		}

		ideas = append(ideas, ideaEntry{
			Slug:          idea.Slug,
			Link:          idea.Link,
			Distance:      idea.Distance,
			Elevation:     idea.Elevation,
			DaysMinLegacy: idea.DaysMin,
			DaysMin:       idea.DaysMin,
			DaysNormal:    idea.DaysNorm,
			Start: stationInfo{
				Name:         startStation.Name,
				Lat:          startStation.Lat,
				Lon:          startStation.Lon,
				TimeDistance: startStation.PoznanTimeDistance(),
			},
			Finish: stationInfo{
				Name:         finishStation.Name,
				Lat:          finishStation.Lat,
				Lon:          finishStation.Lon,
				TimeDistance: finishStation.PoznanTimeDistance(),
			},
			Direction:         direction,
			DirectionChar:     model.CompassNormalized(direction),
			TimeCostStats:     timeCostStats,
			Surfaces:          surfaces,
			Towns:             ideaTowns,
			PhotoMapURL:       "/mapa_zdjec/pomysl/" + idea.Slug + ".svg",
			TownsAlreadyVisit: idea.TownsAlreadyVisited(visitedSlugs),
			TownsNotVisited:   idea.TownsNotVisited(visitedSlugs),
		})
	}

	if len(towns) == 0 {
		towns = []townEntry{}
	}
	if len(ideas) == 0 {
		ideas = []ideaEntry{}
	}

	return NewJSONEndpoint(rtr.IdeasJSON(), ideasData{
		Towns: towns,
		Ideas: ideas,
	})
}

// hasRouteData returns true if the post has any GPS route segments.
func hasRouteData(post *model.Post) bool {
	for _, route := range post.Routes {
		for _, seg := range route.Segments {
			if len(seg) > 0 {
				return true
			}
		}
	}
	return false
}

// RouteColorsJS generates /js/self/route_colors.js from the route colors config.
// This file defines window.ROUTE_STYLES, window.ROUTE_TAG_PRIORITY, and
// window.getRouteStyle() used by area_show.js and other map pages.
func RouteColorsJS(data *index.SiteData) Renderable {
	return NewRawEndpoint("/js/self/route_colors.js", false, func(w io.Writer) error {
		// Collect and sort route types for deterministic output
		types := make([]string, 0, len(data.RouteColors))
		for t := range data.RouteColors {
			types = append(types, t)
		}
		sort.Strings(types)

		fmt.Fprintln(w, "// Auto-generated from data/config/route_colors.yml")
		fmt.Fprintln(w, "window.ROUTE_STYLES = {")
		for i, t := range types {
			rc := data.RouteColors[t]
			comma := ","
			if i == len(types)-1 {
				comma = ""
			}
			fmt.Fprintf(w, "  '%s': { color: '%s', weight: %d, opacity: %g }%s\n",
				t, ensureRGBColor(rc.Color), rc.Weight, rc.Opacity, comma)
		}
		fmt.Fprintln(w, "};")
		fmt.Fprintln(w)

		// Priority order for matching post tags to route styles
		priority := []string{"hike", "bicycle", "e-bike", "canoe", "car", "ev", "bus", "train"}
		fmt.Fprint(w, "window.ROUTE_TAG_PRIORITY = [")
		for i, p := range priority {
			if i > 0 {
				fmt.Fprint(w, ", ")
			}
			fmt.Fprintf(w, "'%s'", p)
		}
		fmt.Fprintln(w, "];")
		fmt.Fprintln(w)

		// Helper function to get route style from post tags
		fmt.Fprintln(w, `window.getRouteStyle = function(tags) {`)
		fmt.Fprintln(w, `  for (var i = 0; i < window.ROUTE_TAG_PRIORITY.length; i++) {`)
		fmt.Fprintln(w, `    if (tags && tags.indexOf(window.ROUTE_TAG_PRIORITY[i]) !== -1) return window.ROUTE_STYLES[window.ROUTE_TAG_PRIORITY[i]];`)
		fmt.Fprintln(w, `  }`)
		fmt.Fprintln(w, `  return window.ROUTE_STYLES.regular;`)
		fmt.Fprintln(w, `};`)

		return nil
	})
}

// ensureRGBColor wraps a color value in rgb() if not already wrapped.
func ensureRGBColor(color string) string {
	if len(color) > 4 && color[:4] == "rgb(" {
		return color
	}
	return "rgb(" + color + ")"
}
