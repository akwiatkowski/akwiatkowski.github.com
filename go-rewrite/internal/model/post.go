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

// PhotoRef represents a photo reference parsed from markdown.
type PhotoRef struct {
	Filename string
	Caption  string
	TagSlugs []string // photo tag slugs ("good", "best", etc.)
	IsHeader bool
}
