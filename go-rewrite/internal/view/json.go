package view

import (
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

// E2EJSON creates a JSON endpoint with all post data for E2E tests.
func E2EJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type postEntry struct {
		Slug     string   `json:"slug"`
		Title    string   `json:"title"`
		URL      string   `json:"url"`
		Date     string   `json:"date"`
		Tags     []string `json:"tags"`
		Towns    []string `json:"towns,omitempty"`
		Lands    []string `json:"lands,omitempty"`
		Distance float64  `json:"distance,omitempty"`
	}

	type e2eData struct {
		Posts []postEntry `json:"posts"`
	}

	result := e2eData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		result.Posts = append(result.Posts, postEntry{
			Slug:     post.Slug,
			Title:    post.Title,
			URL:      rtr.PostURL(post),
			Date:     post.Date.Format("2006-01-02"),
			Tags:     post.TagSlugs,
			Towns:    post.TownSlugs,
			Lands:    post.LandSlugs,
			Distance: post.Distance,
		})
	}

	return NewJSONEndpoint(rtr.E2EJSON(), result)
}

// MapJSON creates a JSON endpoint for the route map page.
func MapJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type routeSegment struct {
		Type   string       `json:"type"`
		Coords [][2]float64 `json:"coords"`
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
						Type:   route.Type,
						Coords: coords,
					})
				}
			}
		}

		result.Posts = append(result.Posts, pe)
	}

	return NewJSONEndpoint(rtr.MapJSON(), result)
}

// PhotosJSON creates a JSON endpoint with all photo metadata.
func PhotosJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type photoEntry struct {
		Desc       string   `json:"desc"`
		FullURL    string   `json:"full_url"`
		ArticleURL string   `json:"article_url"`
		PostSlug   string   `json:"post_slug"`
		PostURL    string   `json:"post_url"`
		Points     int      `json:"points"`
		Tags       []string `json:"tags"`

		// EXIF fields (omitted if nil)
		Lat         *float64 `json:"exif.lat,omitempty"`
		Lon         *float64 `json:"exif.lon,omitempty"`
		Altitude    *float64 `json:"exif.altitude,omitempty"`
		Focal35mm   *float64 `json:"exif.focal_35mm,omitempty"`
		Aperture    *float64 `json:"exif.aperture,omitempty"`
		Exposure    *float64 `json:"exif.exposure,omitempty"`
		ISO         *int     `json:"exif.iso,omitempty"`
		LensName    string   `json:"exif.lens_name,omitempty"`
		CameraName  string   `json:"exif.camera_name,omitempty"`
		ExifTime    string   `json:"exif.time,omitempty"`
	}

	type photosData struct {
		Photos []photoEntry `json:"photos"`
	}

	result := photosData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PhotoEntities {
			if len(photo.Desc) < 4 {
				continue
			}
			pe := photoEntry{
				Desc:       photo.Desc,
				FullURL:    rtr.PostImageURL(post, photo.ImageFilename),
				ArticleURL: rtr.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
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
				if photo.Exif.Time != nil {
					pe.ExifTime = photo.Exif.Time.Format("2006-01-02 15:04:05")
				}
			}
			result.Photos = append(result.Photos, pe)
		}
	}

	return NewJSONEndpoint(rtr.PhotosJSON(), result)
}

// PhotosMapJSON creates a JSON endpoint with GPS-tagged photos for map markers.
func PhotosMapJSON(data *index.SiteData, rtr *router.Router) Renderable {
	type photoEntry struct {
		Lat      float64 `json:"lat"`
		Lon      float64 `json:"lon"`
		PostSlug string  `json:"post_slug"`
		Filename string  `json:"filename"`
		Desc     string  `json:"desc"`
	}

	type photosMapData struct {
		Photos []photoEntry `json:"photos"`
	}

	result := photosMapData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PhotoEntities {
			if !photo.HasGPS() {
				continue
			}
			result.Photos = append(result.Photos, photoEntry{
				Lat:      *photo.Exif.Lat,
				Lon:      *photo.Exif.Lon,
				PostSlug: post.Slug,
				Filename: photo.ImageFilename,
				Desc:     photo.Desc,
			})
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
		for _, photo := range post.PhotoEntities {
			if !photo.HasGPS() {
				continue
			}
			result.Coords = append(result.Coords, [2]float64{*photo.Exif.Lat, *photo.Exif.Lon})
		}
	}

	return NewJSONEndpoint(rtr.PhotoGridJSON(), result)
}

// IdeasJSON creates a JSON endpoint for trip ideas data.
func IdeasJSON(rtr *router.Router) Renderable {
	// Ideas data is not yet loaded in the Go pipeline.
	// Output empty structure for now; will be populated when ideas loading is added.
	type ideasData struct {
		Towns []any `json:"towns"`
		Ideas []any `json:"ideas"`
	}

	return NewJSONEndpoint(rtr.IdeasJSON(), ideasData{
		Towns: []any{},
		Ideas: []any{},
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
