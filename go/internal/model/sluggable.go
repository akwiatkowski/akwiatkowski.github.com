package model

// Sluggable is implemented by entities that have a URL-safe slug identifier.
type Sluggable interface {
	GetSlug() string
}

// GetSlug returns the tag's English slug.
func (t *Tag) GetSlug() string { return t.Slug }

// GetSlug returns the photo tag's slug.
func (t *PhotoTag) GetSlug() string { return t.Slug }

// GetSlug returns the area's slug.
func (a *Area) GetSlug() string { return a.Slug }

// GetSlug returns the post's slug.
func (p *Post) GetSlug() string { return p.Slug }
