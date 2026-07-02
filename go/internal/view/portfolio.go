package view

import (
	"encoding/json"
	"fmt"
	"sort"

	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/view/template/layout"
	"odkrywajac/internal/view/template/views"
)

const maxPortfolioPhotos = 70

// PortfolioPage creates a Renderable for the photo portfolio page.
// It displays a hero photo, stats, and a masonry grid of best photos
// using the Preact portfolio.js component (mounts on #portfolio-root).
//
// Photo selection uses a 3-tier algorithm matching Crystal:
// 1. "portfolio" tagged photos
// 2. "best" tagged photos
// 3. "good" tagged photos (if needed to fill up to 70)
func PortfolioPage(
	data *catalog.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := rtr.PortfolioURL()

	photos := selectPortfolioPhotos(data)
	jsonData := buildPortfolioJSON(data, rtr, photos)
	rawScript := `<script id="portfolio-data" type="application/json">` + jsonData + `</script>`

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "react-runtime"}, []string{"portfolio", "photo-lightbox"})

	// og:image uses the hero photo (highest-ranked portfolio photo), so social
	// shares of /portfolio.html preview the same image the page opens with.
	var heroImageURL string
	if len(photos) > 0 {
		hero := photos[0]
		if heroPost := data.PostBySlug(hero.PostSlug); heroPost != nil {
			heroImageURL = rtr.ProcessedImageURL(heroPost, hero.ImageFilename, "article", "jpg")
		}
	}

	page := layout.PageData{
		Title:        "Portfolio",
		Desc:         "Portfolio fotograficzne. Rowerem i pieszo przez Polskę.",
		ImageURL:     heroImageURL,
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJSFiles:       []string{"/js/self/portfolio.js"},
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.PortfolioContent(rawScript), true)
}

// selectPortfolioPhotos picks photos using 3-tier selection: portfolio > best > good,
// sorted by points descending, limited to maxPortfolioPhotos.
func selectPortfolioPhotos(data *catalog.SiteData) []*model.Photo {
	seen := make(map[string]bool)
	var result []*model.Photo

	// Helper to add photos matching a tag
	addTag := func(tag string) {
		for _, post := range data.Posts {
			if !post.IsFinished() {
				continue
			}
			for _, photo := range post.PublishedPhotos {
				key := post.Slug + "/" + photo.ImageFilename
				if seen[key] {
					continue
				}
				for _, t := range photo.TagSlugs {
					if t == tag {
						result = append(result, photo)
						seen[key] = true
						break
					}
				}
			}
		}
	}

	addTag("portfolio")
	addTag("best")
	if len(result) < maxPortfolioPhotos {
		addTag("good")
	}

	// Sort by points descending
	sort.Slice(result, func(i, j int) bool {
		return result[i].Points > result[j].Points
	})

	if len(result) > maxPortfolioPhotos {
		result = result[:maxPortfolioPhotos]
	}

	return result
}

// buildPortfolioJSON generates the JSON data inlined in the portfolio page.
// Matches Crystal's PortfolioView data contract for portfolio.js.
func buildPortfolioJSON(data *catalog.SiteData, r *router.Router, photos []*model.Photo) string {
	type heroPhoto struct {
		Src     string `json:"src"`
		SrcAVIF string `json:"src_avif"`
		FullSrc string `json:"full_src"`
		Alt     string `json:"alt"`
	}

	type stats struct {
		BicycleDistanceKm int    `json:"bicycle_distance_km"`
		HikeDistanceKm    int    `json:"hike_distance_km"`
		TotalHours        int    `json:"total_hours"`
		PostCount         int    `json:"post_count"`
		PhotoCount        int    `json:"photo_count"`
		YearsActive       string `json:"years_active"`
		TownsVisited      int    `json:"towns_visited"`
	}

	type exifData struct {
		Camera   *string `json:"camera"`
		Lens     *string `json:"lens"`
		Focal    *string `json:"focal"`
		Aperture *string `json:"aperture"`
		Exposure *string `json:"exposure"`
		ISO      *int    `json:"iso"`
	}

	type photoEntry struct {
		Src        string   `json:"src"`
		SrcAVIF    string   `json:"src_avif"`
		GridSrc    string   `json:"grid_src"`
		GridAVIF   string   `json:"grid_src_avif"`
		FullSrc    string   `json:"full_src"`
		FullAVIF   string   `json:"full_src_avif"`
		Alt        string   `json:"alt"`
		PostURL    string   `json:"post_url"`
		PostTitle  string   `json:"post_title"`
		Points     int      `json:"points"`
		Tags       []string `json:"tags"`
		Exif       exifData `json:"exif"`
	}

	type portfolioJSON struct {
		HeroPhoto *heroPhoto   `json:"hero_photo,omitempty"`
		Stats     stats        `json:"stats"`
		Photos    []photoEntry `json:"photos"`
	}

	// Compute stats from all finished posts
	var bicycleDist, hikeDist, totalHours float64
	var postCount, photoCount int
	var minYear, maxYear int
	townSet := make(map[string]bool)

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		postCount++
		photoCount += len(post.PublishedPhotos)

		year := post.Date.Year()
		if minYear == 0 || year < minYear {
			minYear = year
		}
		if year > maxYear {
			maxYear = year
		}

		for _, tag := range post.TagSlugs {
			if tag == "bicycle" || tag == "e-bike" {
				bicycleDist += post.Distance
			}
			if tag == "hike" {
				hikeDist += post.Distance
			}
		}
		totalHours += post.TimeSpent

		for _, slug := range post.TownSlugs {
			townSet[slug] = true
		}
	}

	yearsStr := ""
	if minYear > 0 {
		yearsStr = fmt.Sprintf("%d-%d", minYear, maxYear)
	}

	pj := portfolioJSON{
		Stats: stats{
			BicycleDistanceKm: int(bicycleDist),
			HikeDistanceKm:    int(hikeDist),
			TotalHours:        int(totalHours),
			PostCount:         postCount,
			PhotoCount:        photoCount,
			YearsActive:       yearsStr,
			TownsVisited:      len(townSet),
		},
		Photos: make([]photoEntry, 0, len(photos)),
	}

	// Hero photo from first photo
	if len(photos) > 0 {
		hero := photos[0]
		heroPost := data.PostBySlug(hero.PostSlug)
		if heroPost != nil {
			pj.HeroPhoto = &heroPhoto{
				Src:     r.ProcessedImageURL(heroPost, hero.ImageFilename, "article", "jpg"),
				SrcAVIF: r.ProcessedImageURL(heroPost, hero.ImageFilename, "article", "avif"),
				FullSrc: r.PostImageURL(heroPost, hero.ImageFilename),
				Alt:     hero.Desc,
			}
		}
	}

	// Photo entries
	for _, photo := range photos {
		post := data.PostBySlug(photo.PostSlug)
		if post == nil {
			continue
		}

		pe := photoEntry{
			Src:       r.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
			SrcAVIF:   r.ProcessedImageURL(post, photo.ImageFilename, "article", "avif"),
			GridSrc:   r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
			GridAVIF:  r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
			FullSrc:   r.PostImageURL(post, photo.ImageFilename),
			FullAVIF:  "",
			Alt:       photo.Desc,
			PostURL:   r.PostURL(post),
			PostTitle: post.Title,
			Points:    photo.Points,
			Tags:      photo.TagSlugs,
		}

		if photo.Exif != nil {
			if photo.Exif.CameraName != "" {
				pe.Exif.Camera = &photo.Exif.CameraName
			}
			if photo.Exif.LensName != "" {
				pe.Exif.Lens = &photo.Exif.LensName
			}
			if photo.Exif.FocalLength != nil {
				s := fmt.Sprintf("%dmm", int(*photo.Exif.FocalLength))
				pe.Exif.Focal = &s
			}
			if photo.Exif.Aperture != nil && *photo.Exif.Aperture > 0.1 {
				s := fmt.Sprintf("f/%s", fmtAperture(*photo.Exif.Aperture))
				pe.Exif.Aperture = &s
			}
			if photo.Exif.ExposureString != "" {
				pe.Exif.Exposure = &photo.Exif.ExposureString
			}
			if photo.Exif.ISO != nil {
				pe.Exif.ISO = photo.Exif.ISO
			}
		}

		pj.Photos = append(pj.Photos, pe)
	}

	jsonBytes, _ := json.Marshal(pj)
	return string(jsonBytes)
}
