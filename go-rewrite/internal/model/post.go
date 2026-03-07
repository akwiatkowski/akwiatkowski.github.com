package model

import (
	"fmt"
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
	TagSlugs  []string
	TownSlugs []string
	LandSlugs []string

	// Activity
	CoordsFile  string
	CoordsType  string
	Distance    float64
	TimeSpent   float64
	Elevation   int
	Temperature *int
	Strava      []string // strava URLs or IDs

	// Parsed from body
	Photos        []PhotoRef
	HeaderPhoto   *PhotoRef
	CrossRefSlugs []string // post slugs from {% post_url %}
	Content       string   // raw markdown body

	// Loaded separately
	Routes        []Route
	PhotoEntities []*Photo
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

// BuildURL constructs the post URL from date and slug.
func BuildPostURL(date time.Time, slug string) string {
	return fmt.Sprintf("/%d/%02d/%02d-%s.html", date.Year(), date.Month(), date.Day(), slug)
}

// PhotoByFilename finds a loaded Photo entity by its filename.
func (p *Post) PhotoByFilename(filename string) *Photo {
	for _, photo := range p.PhotoEntities {
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

// IsPhotoOfTheYear returns true if tagged "photo_of_the_year".
func (p *Post) IsPhotoOfTheYear() bool { return p.HasTag("photo_of_the_year") }

// PhotoRef represents a photo reference parsed from markdown.
type PhotoRef struct {
	Filename string
	Caption  string
	TagSlugs []string // photo tag slugs ("good", "best", etc.)
	IsHeader bool
}
