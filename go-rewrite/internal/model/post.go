package model

import (
	"time"
)

// Post represents a blog post with its metadata and content.
type Post struct {
	// Identity
	Slug     string
	Title    string
	Subtitle string
	Desc     string
	Author   string
	Category string
	URL      string // /YYYY/MM/DD-slug.html
	Date     time.Time
	FinishedAt *time.Time
	Keywords []string

	// Header image
	ImageFilename string
	ImagePosition string

	// Tags & areas (slugs from front matter)
	TagSlugs     []string
	TownSlugs    []string
	LandSlugs    []string
	ForeignSlugs []string

	// Areas the route actually passed through, per type, from the spatial
	// route→area coverage cache (loader.EnrichPostsWithAreaCache). Unlike the
	// frontmatter slugs above these carry exact disambiguated slugs (e.g.
	// grudziadz-kujawsko-pomorskie-miejska) and cover counties and macro
	// regions that authors never list by hand. Nil when no coverage exists.
	SpatialAreaSlugs map[AreaType][]string

	// Activity
	CoordsFile  string
	CoordsType  string
	Distance    float64
	TimeSpent   float64
	Elevation   int
	Temperature *int
	Strava      []string // strava URLs or IDs

	// Parsed from body
	PublishedPhotoRefs []PhotoRef
	HeaderPhotoRef     *PhotoRef
	CrossRefSlugs      []string // post slugs from {% post_url %}
	Content            string   // raw markdown body

	// Loaded separately
	Routes          []Route
	PublishedPhotos []*Photo // photos from markdown {% photo %} tags, enriched with EXIF
	AllPhotos       []*Photo // all photos from post's image directory (superset of PublishedPhotos)
}

// IsFinished returns true if the post has a finished_at date in the past.
func (p *Post) IsFinished() bool {
	if p.FinishedAt == nil {
		return false
	}
	return p.FinishedAt.Before(time.Now())
}

// Year returns the post's year.
func (p *Post) Year() int {
	return p.Date.Year()
}

// SlugName returns the name part of the slug without the date prefix.
// e.g., "2021-07-24-w-trakcie-zniw" → "w-trakcie-zniw"
func (p *Post) SlugName() string {
	// Slug format: YYYY-MM-DD-name, strip first 11 chars
	if len(p.Slug) > 11 {
		return p.Slug[11:]
	}
	return p.Slug
}

// PublishedPhotoByFilename finds a published Photo by its image filename.
// Used by the markdown renderer to look up photo metadata during article rendering.
func (p *Post) PublishedPhotoByFilename(filename string) *Photo {
	for _, photo := range p.PublishedPhotos {
		if photo.ImageFilename == filename {
			return photo
		}
	}
	return nil
}

// HasTag returns true if the post has the given tag slug.
func (p *Post) HasTag(slug string) bool {
	for _, s := range p.TagSlugs {
		if s == slug {
			return true
		}
	}
	return false
}

// IsBicycle returns true if post is tagged "bicycle".
func (p *Post) IsBicycle() bool { return p.HasTag("bicycle") }

// IsHike returns true if post is tagged "hike".
func (p *Post) IsHike() bool { return p.HasTag("hike") }

// IsWalk returns true if post is tagged "walk".
func (p *Post) IsWalk() bool { return p.HasTag("walk") }

// IsTrain returns true if post is tagged "train".
func (p *Post) IsTrain() bool { return p.HasTag("train") }

// IsSelfPropelled returns true if post is bicycle, hike, or walk.
func (p *Post) IsSelfPropelled() bool {
	return p.IsBicycle() || p.IsHike() || p.IsWalk()
}

// HasRoutes returns true if the post has non-empty route data.
func (p *Post) HasRoutes() bool {
	return len(p.Routes) > 0 && len(p.Routes[0].Segments) > 0
}

// RoutesCoordRange computes the bounding box of all route segments.
// Returns the range and true if routes exist, or zero value and false otherwise.
func (p *Post) RoutesCoordRange() (CoordRange, bool) {
	if !p.HasRoutes() {
		return CoordRange{}, false
	}
	first := true
	var cr CoordRange
	for _, route := range p.Routes {
		for _, seg := range route.Segments {
			for _, pt := range seg {
				if first {
					cr = CoordRange{LatFrom: pt.Lat, LatTo: pt.Lat, LonFrom: pt.Lon, LonTo: pt.Lon}
					first = false
				} else {
					if pt.Lat < cr.LatFrom {
						cr.LatFrom = pt.Lat
					}
					if pt.Lat > cr.LatTo {
						cr.LatTo = pt.Lat
					}
					if pt.Lon < cr.LonFrom {
						cr.LonFrom = pt.Lon
					}
					if pt.Lon > cr.LonTo {
						cr.LonTo = pt.Lon
					}
				}
			}
		}
	}
	return cr, !first
}

// IsPhotoOfTheYear returns true if tagged "photo_of_the_year".
func (p *Post) IsPhotoOfTheYear() bool { return p.HasTag("photo_of_the_year") }

// PhotoRef represents a photo reference parsed from markdown.
type PhotoRef struct {
	Filename string
	Caption  string
	TagSlugs []string // photo tag slugs ("good", "best", etc.)
	IsHeader bool
}
