package view

import (
	"encoding/json"
	"math"
	"sort"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

const (
	autoPoiClusterRadiusM = 500.0
	autoPoiDedupDistanceM = 20000.0
	autoPoiMaxCount       = 20
)

// POIsPage creates a Renderable for the POIs page.
func POIsPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.POIsURL()

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "leaflet", "react-runtime"}, []string{"pois"})

	page := layout.PageData{
		Title:        "Ciekawe miejsca",
		Desc:         "Punkty zainteresowania odwiedzone i planowane",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJS:       "/js/self/pois.js",
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	pois := buildPOIs(data, r)
	poisJSON, _ := json.Marshal(map[string]interface{}{"pois": pois})
	rawScript := `<script id="pois-data" type="application/json">` + string(poisJSON) + `</script>`

	return NewHTMLPage(url, page, views.POIsContent(rawScript), true)
}

func buildPOIs(data *index.SiteData, r *router.Router) []views.POIEntry {
	var result []views.POIEntry

	// Manual POIs from TransportPOIs
	for _, poi := range data.POIs {
		entry := views.POIEntry{
			Name: poi.Name,
			Lat:  poi.Lat,
			Lon:  poi.Lon,
			Type: "visited",
		}

		// Find closest geotagged photo
		if photo, post := findClosestPhoto(poi.Lat, poi.Lon, data); photo != nil {
			entry.PhotoURL = r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg")
			entry.PhotoAVIF = r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif")
			entry.PhotoDesc = photo.Desc
			entry.PostTitle = post.Title
			entry.PostURL = r.PostURL(post)
		}

		result = append(result, entry)
	}

	// Auto-POIs from best geotagged photos
	autoPOIs := buildAutoPOIs(data, r, result)
	result = append(result, autoPOIs...)

	return result
}

func buildAutoPOIs(data *index.SiteData, r *router.Router, manualPOIs []views.POIEntry) []views.POIEntry {
	// Collect all geotagged photos with points
	type scoredPhoto struct {
		photo *model.Photo
		post  *model.Post
	}
	var candidates []scoredPhoto
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if photo.HasGPS() && photo.Points > 0 {
				candidates = append(candidates, scoredPhoto{photo, post})
			}
		}
	}

	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].photo.Points > candidates[j].photo.Points
	})

	var autoPOIs []views.POIEntry
	var selectedCoords [][2]float64

	for _, c := range candidates {
		if len(autoPOIs) >= autoPoiMaxCount {
			break
		}

		lat := *c.photo.Exif.Lat
		lon := *c.photo.Exif.Lon

		// Skip if within dedup distance of manual POI
		tooClose := false
		for _, mp := range manualPOIs {
			if haversineM(lat, lon, mp.Lat, mp.Lon) < autoPoiDedupDistanceM {
				tooClose = true
				break
			}
		}
		if tooClose {
			continue
		}

		// Skip if within cluster radius of already-selected
		for _, sc := range selectedCoords {
			if haversineM(lat, lon, sc[0], sc[1]) < autoPoiClusterRadiusM {
				tooClose = true
				break
			}
		}
		if tooClose {
			continue
		}

		selectedCoords = append(selectedCoords, [2]float64{lat, lon})
		autoPOIs = append(autoPOIs, views.POIEntry{
			Name:      c.photo.Desc,
			Lat:       lat,
			Lon:       lon,
			Type:      "auto",
			PhotoURL:  r.ProcessedImageURL(c.post, c.photo.ImageFilename, "grid", "jpg"),
			PhotoAVIF: r.ProcessedImageURL(c.post, c.photo.ImageFilename, "grid", "avif"),
			PhotoDesc: c.photo.Desc,
			PostTitle: c.post.Title,
			PostURL:   r.PostURL(c.post),
		})
	}

	return autoPOIs
}

func findClosestPhoto(lat, lon float64, data *index.SiteData) (*model.Photo, *model.Post) {
	var bestPhoto *model.Photo
	var bestPost *model.Post
	bestDist := math.MaxFloat64

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if !photo.HasGPS() {
				continue
			}
			d := haversineM(*photo.Exif.Lat, *photo.Exif.Lon, lat, lon)
			if d < bestDist {
				bestDist = d
				bestPhoto = photo
				bestPost = post
			}
		}
	}

	return bestPhoto, bestPost
}

// haversineM returns distance in meters between two lat/lon points.
func haversineM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000.0 // meters
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadius * c
}
